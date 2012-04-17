package Net::Symon::NetBrite;

our $VERSION = '0.01';

=head1 NAME

Net::Symon::NetBrite - Talk to Symon NetBrite LED signs

=head1 SYNOPSIS

    use Net::Symon::NetBrite qw(:constants);
    use Net::Symon::NetBrite::Zone;

    my $sign = new Net::Symon::NetBrite(
        address => '192.168.34.56',
    );

    my $zone = new Net::Symon::NetBrite::Zone(
        rect => [0, 0, 200, 24],
        default_font => 'monospace_16',
    );

    $sign->zones(
        myzone => $zone,
    );

    $sign->message('myzone', '{green}west philadelphia {red}born and raised');

    $sign->reboot();

=head1 DESCRIPTION

Do you have a bunch of Symon NetBrite II signs laying around from a
company you acquired that had more money than sense?  So do we!

=cut

use IO::Socket::INET;
use Digest::CRC;
use Carp;
require Exporter;

use constant {
    COLOR_RED => 0x01,
    COLOR_GREEN => 0x02,
    COLOR_YELLOW => 0x03,

    SCROLL_SLOW => 0x01,
    SCROLL_MED => 0x02,
    SCROLL_FAST => 0x03,

    PRI_OVERRIDE => 0x01,
    PRI_INTERRUPT => 0x02,
    PRI_FOLLOW => 0x03,
    PRI_YIELD => 0x04,
    PRI_ROUNDROBIN => 0x0a,
};

our %fonts = (
    monospace_16 => 0x00,
    proportional_7 => 0x01,
    proportional_5 => 0x02,
    proportional_11 => 0x03,
    monospace_24 => 0x04,
    bold_proportional_7 => 0x05,
    bold_proportional_11 => 0x06,
    monospace_7 => 0x07,
    script_16 => 0x08,
    proportional_9 => 0x09,
    picture_24 => 0x0a,
);

our @ISA = qw(Exporter);
my @consts = qw(    COLOR_RED COLOR_GREEN COLOR_YELLOW
                    SCROLL_SLOW SCROLL_MED SCROLL_FAST
                    PRI_OVERRIDE PRI_INTERRUPT PRI_FOLLOW PRI_YIELD PRI_ROUNDROBIN);
our @EXPORT_OK = @consts;
our %EXPORT_TAGS = ( constants => \@consts );

=head1 METHODS

=head2 new()

Creates a new instance, which handles a single sign.  The following
parameters are accepted:

=over

=item address

The address of the sign.

=item port

(optional) The destination port.  Defaults to 700.

=item callback

If supplied, no socket will be created.  Instead, the supplied coderef
will be called with a single argument whenever data needs to be sent.
This is intended for use with an external framework like L<POE|POE>.

=back

=cut

sub new {
    my ($class, %data) = @_;
    my $self = {};

    if ($data{callback}) {
        $self->{callback} = $data{callback};
    } elsif ($data{address}) {
        $self->{addr} = $data{address};
        $self->{port} = $data{port} || 700;
    } else {
        croak 'Either address or callback must be supplied';
    }

    $self->{seqno} = 0;
    $self->{sessno} = 0;

    bless($self, $class);
    return $self;
}

sub pkt_escape {
    my $pkt = shift;
    my $esc = pack('C', 0x10);
    my $buf;

    for (my $i = 0; $i < length $pkt; $i++) {
        my $byte = unpack("x[$i]C", $pkt);

        if ($i > 4 && $i < length($pkt) - 4 && ($byte == 0x10 || $byte == 0x01 || $byte == 0x04 || $byte == 0x17)) {
            $buf .= $esc;
        }

        $buf .= pack('C', $byte);
    }

    return $buf;
}

sub crc { return Digest::CRC::crc(shift, 16, 0x0000, 0x0000, 1, 0x1021, 1, 0) }

sub tx {
    my ($self, $pkt) = @_;

    if (defined $self->{callback}) {
        $self->{callback}->($pkt);
    } else {
        $self->{sock}->send($pkt);
        $self->{sock}->flush();
    }
}

sub connect {
    my $self = shift;

    $self->{sock} = IO::Socket::INET->new(
        PeerAddr => $self->{addr},
        PeerPort => 700,
        Proto => 'tcp',
    );

    unless (defined $self->{sock}) {
        croak "Socket: $!";
    }

    $self->{sessno} = 0;
    #$self->zones();
}

=head2 zones()

Updates the list of zones associated with the sign.  Any existing
zones are replaced.  The zones will be sent to the sign immediately
and upon every successful reconnection.

The only parameter is a hash, in which the keys are zone names and the
values are L<Net::Symon::NetBrite::Zone|Net::Symon::NetBrite::Zone>
objects.

If called without a list of zones, the last provided zones will be
sent to the sign again.

=cut

sub zones {
    my ($self, %zones) = @_;

    if (%zones) {
        $self->{zones} = \%zones;
    } elsif (!defined $self->{zones}) {
        return undef;
    }

    if (!defined $self->{sock}) {
        $self->connect();
    }


    my $zid = 1;
    foreach my $zname (sort { $a cmp $b } keys %{$self->{zones}}) {
        my $z = $self->{zones}->{$zname};
        $z->id($zid);

        my $ztext = &parse_msg($z->get('initial_text'));
        my $zlen = length $ztext;

        my $body = pack("C4 CC4 C3 Cv C8 C C4 C4 vC5 C10 C3 C20vC3C11A[$zlen] C",
            0x0f, 0x00, 0x0e, 0x02, # body start
            $zid, @{$z->get('rect')}, # zone def
            0x0d, $z->get('scroll_speed'), 0x00, # scroll rate
            0x0c, $z->get('pause_duration'), # pause duration
            0x0b, 0xfe, 0x0a, 0xe8, 0x03, 0x09, 0x0e, 0x08, # msg def params
            $z->get('volume'), # volume (0-8)
            0x07, $fonts{$z->get('default_font')}, 0x06, $z->get('default_color'), # default font
            0x05, 0x00, 0x00, 0x04, # font footer
            2012, 2, 10, 19, 21, 33, # timestamp: yyyy, mo, d, h, min, sec?
            #                                         tfmt
            0x00, 0x03, 0x00, 0x00, 0x2f, 0x02, 0xff, 0x10, 0x3a, 0x01, # def message hdr
            $zid, 0x00, 0x03,
            # it's magic, i ain't gotta explain shit
            #0x0e, 0x00,
            0x02, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x03, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0xfe,
            0x7e, 0x00, 0x02, 0x00,
            $zlen, 0x00, 0x00, 0x04,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0xfe, 0x7e, 0x00, $ztext,
            0x17, # body end
        );

        my $header = pack('C3 v v C3 C2 C4 C2 C2',
            0x16, 0x16, 0x01, # msg start
            length($body),
            ++$self->{seqno},
            0x00, 0x01, 0x00,
            0x01, 0x01, # type = init
            0x00, 0xc8, 0x01, 0x00, # sign id
            0x00, ++$self->{sessno}, # session packet count
            0x04, 0x00, # header end
        );

        my $footer = pack('vC',
            crc($header.$body),
            0x04, # msg end
        );

        $self->tx(&pkt_escape($header.$body.$footer));

        print "sent zone $zid with seqno ", $self->{seqno}, " sessno ", $self->{sessno}, "\n";

        $zid++;
    }
}

=head2 message()

Sends a message to a zone.  Accepts the zone name, message text and an
optional hashref containing any of the following parameters:

=over

=item priority

The message priority determines how the new message will replace an
existing one.  The default is C<PRI_FOLLOW>, but can also be
C<PRI_OVERRIDE>, C<PRI_INTERRUPT>, C<PRI_YIELD> or C<PRI_ROUNDROBIN>.

=item activation_delay

Message activation delay in milliseconds.  Default is 0.

=item display_deplay

Message display delay in milliseconds.  Default is 0.

=item display_repeat

Not really sure.  The default is 0.

=item ttl

The message will self-destruct in C<ttl> seconds.  Default is 0.

=item sound_alarm

If true, the sign will beep when the message is displayed.

=back

=cut

sub message {
    my ($self, $zname, $text, $param) = @_;
    my $z = $self->{zones}->{$zname};

    unless ($z) {
        return undef;
    }

    print "sending to zone $zname with id ", $z->id, "\n";

    my $ztext = &parse_msg($text);
    my $zlen = length $ztext;

    # uck
    if ($zlen == 4 || $zlen == 5) {
        $ztext = pack('C2', 0x10, 0x15).$ztext;
        $zlen += 2;
    }

    my $body = pack("V C v v v v C C2 A[$zlen] C",
        $zlen,
        $param->{priority} || PRI_OVERRIDE,
        $param->{activation_delay} || 0,
        $param->{display_delay} || 0,
        $param->{display_repeat} || 0,
        $param->{ttl} || 0,
        ($param->{sound_alarm} ? 0xff : 0xfe),
        0x00, 0x00, # msg slot
        $ztext,
        0x17, # body end
    );

    my $maskbytes = $z->id / 8;
    if (int($maskbytes) != $maskbytes) { $maskbytes = int($maskbytes) + 1 }
    my $zmask = pack($z->id > 0xff ? 'v' : 'C', 1 << ($z->id - 1));
    my $zmlen = length $zmask;

    printf("zmask: %s bytes: %d\n", unpack('H*', $zmask), $maskbytes);

    my $header = pack("C3 v v C3 C2 Ca[$zmlen] C2",
        0x16, 0x16, 0x01, # msg start
        length($body) + 1,
        ++$self->{seqno},
        0x00, 0x01, 0x00,
        0x03, $maskbytes * 8,
        0x00, $zmask,
        0x02, 0x00, # header end
    );

    my $footer = pack('vC',
        crc($header.$body),
        0x04, # msg end
    );

    $self->tx(&pkt_escape($header.$body.$footer));
}

=head2 reboot()

Instructs the sign to reboot.

=cut

sub reboot {
    my $self = shift;

    my $pkt = pack('C3vvC4C*',
        0x16, 0x16, 0x01, # msg start
        2, # body length
        ++$self->{seqno}, # packet count
        0x00, 0x01, 0x00,
        0x01, 0x01, # msg type: reset
        0x00, 0xc8, 0x01, 0x00, # sign id
        0x00, 0x01, 0x0f, 0x00, # reset msg
        0x17, # crc follows
    );

    $pkt .= pack('vC',
        crc($pkt),
        0x04, # msg end
    );

    $self->tx(&pkt_escape($pkt));
}

=head1 Message Formatting

The NetBrite signs have a few formatting switches that can be applied
in-line to messages.  This is implemented as a kind of markup.

=over

=item C<{scrolloff}>, C<{scrollon}>

Turns scrolling on or off.  This works in the middle of a message, but
seems to have a tendency to mess things up.

=item C<{blinkon}>, C<{blinkoff}>

Turns blinking on or off.

=item C<{red}>, C<{green}>, C<{yellow}>

Changes the text color.

=item C<{left}>, C<{center}>, C<{right}>

Changes the text's alignment within its zone.

=item C<{pause}>

Briefly pauses the display, probably for the amount of time specified
in the zone definition.

=item C<{erase}>

Erases.

=item C<{serial}>

Inserts the sign's serial number, which seems to always be its
Ethernet MAC address.

=item C<{bell}>

Beeps.

=item C<{note [pitch] [duration]}>

Beeps at C<pitch> for C<duration>.  The pitch is a positive integer, possibly
0-254 and the duration is in milliseconds.

=item C<{tune [1-9] ["repeat"]}>

Plays one of nine predefined tunes.  #9 is Charge!

If I<repeat> is specified, the tune will play every time the message is
displayed.  This is extremely annoying.

=item C<{font [font_name]}>

Switches to C<font_name>.  See L</Available Fonts>.

Note that the sign won't change to a font that's taller than its
containing zone.

=back

=head1 Available Fonts

The following fonts are available:

=over

=item monospace_7

=item monospace_16

=item monospace_24

=item proportional_7

=item proportional_5

=item proportional_9

=item proportional_11

=item bold_proportional_7

=item bold_proportional_11

=item script_16

=item picture_24

=back

=cut

sub parse_msg {
    my $msg = shift;

    $msg =~ s!\{scrolloff\}!pack('C*', 0x10, 0x14)!ieg;
    $msg =~ s!\{scrollon\}!pack('C*', 0x10, 0x15)!ieg;

    $msg =~ s!\{blinkoff\}!pack('C*', 0x10, 0x01)!ieg;
    $msg =~ s!\{blinkon\}!pack('C*', 0x10, 0x00)!ieg;

    $msg =~ s!\{red\}!pack('C*', 0x10, 0x0c, COLOR_RED)!ieg;
    $msg =~ s!\{green\}!pack('C*', 0x10, 0x0c, COLOR_GREEN)!ieg;
    $msg =~ s!\{yellow\}!pack('C*', 0x10, 0x0c, COLOR_YELLOW)!ieg;

    $msg =~ s!\{left\}!pack('C*', 0x10, 0x27)!ieg;
    $msg =~ s!\{center\}!pack('C*', 0x10, 0x29)!ieg;
    $msg =~ s!\{right\}!pack('C*', 0x10, 0x28)!ieg;

    $msg =~ s!\{pause\}!pack('C*', 0x10, 0x05)!ieg;
    $msg =~ s!\{erase\}!pack('C*', 0x10, 0x03)!ieg;
    $msg =~ s!\{serial\}!pack('C*', 0x10, 0x09)!ieg;
    $msg =~ s!\{bell\}!pack('C*', 0x10, 0x05)!ieg;
    $msg =~ s!\{note\s+(\d+)\s+(\d+)\}!pack('C2Cv', 0x10, 0x11, $1, $2)!ieg;
    $msg =~ s!\{tune\s+([1-9])(\s+repeat)?\}!pack('C2C', 0x10, ($2 ? 0x0a : 0x0b), $1)!ieg;
    $msg =~ s!\{font\s+(\S+)\}!pack('C2C', 0x10, 0x0d, $fonts{$1})!ieg;

    return $msg;
}

=head1 BUGS

There is no error checking of any kind.

Handling of sequence numbers should probably be better.

We don't bother to set the time on the sign, or do any of the
time/date formatting stuff.  Sorry, I don't use it; send patches.

No support for message slots.

Socket handling stuff is embarrassing.

=head1 AUTHOR

Ben Wilber <ben@desync.com>

Most of the credit goes to the author of
L<NetPenguin Server|http://www.thepenguinmaster.com/>, who did the
hard work of figuring out the protocol.  Consider supporting that
project if you find this useful.

=head1 LICENSE

This library is free software and may be distributed under the same
terms as Perl itself.

=cut

1;
