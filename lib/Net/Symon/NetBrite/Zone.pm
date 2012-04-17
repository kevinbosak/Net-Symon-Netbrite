package Net::Symon::NetBrite::Zone;
require Carp;

=head1 NAME

Net::Symon::NetBrite::Zone - Define a NetBrite zone

=head1 SYNOPSIS

    my $zone = new Net::Symon::NetBrite::Zone(
        rect => [0, 0, 200, 24],
    );

=head1 CREATING A ZONE

To create a zone, call C<new()>.  The only required parameter is C<rect>; the
rest are optional.

=over

=item rect

Accepts an arrayref that defines the position and size of the zone in LEDs.
The first two parameters are the upper left bound of the rectangle.  The last
two are the lower right bound.  For example,

    rect => [10, 10, 20, 20]

would create a 10x10 area 10 LEDs from the top left corner.

B<ACHTUNG:> Don't create zones that overlap, are bigger than your sign,
zero/negative size or other stupidity.  This can crash or hang your sign.

=item scroll_speed

The speed of scrolling text in the zone.  The default is C<SCROLL_MED>, but can
also be C<SCROLL_SLOW> or C<SCROLL_FAST>.

=item pause_duration

The duration in milliseconds of any pause sequences in the message text.  I
think.

=item volume

The volume of beeps, notes, alarms and other noises.  Valid range is 0 (off) to
8 (deadly).  Default is 4.

=item default_font

The default font.  See L<Net::Symon::NetBrite/available_fonts>.

=item default_color

The default color.  Can be C<COLOR_RED>, C<COLOR_GREEN> or C<COLOR_YELLOW>.
The default is red.

=item initial_text

The text initially displayed in the zone.  This is just "." by default.

=back

=cut

sub new {
    my ($class, %data) = @_;
    my $self = {};

    if (defined $data{rect}) {
        $self->{rect} = $data{rect};
    } else {
        croak("Must supply rect");
    }

    $self->{scroll_speed} = $data{scroll_speed} || Net::Symon::NetBrite::SCROLL_MED;

    $self->{pause_duration} = $data{pause_duration} || 1000;

    $self->{volume} = $data{volume} || 4;

    $self->{default_font} = $data{default_font} || 'proportional_5';

    $self->{default_color} = $data{default_color} || Net::Symon::NetBrite::COLOR_RED;

    $self->{initial_text} = $data{initial_text} || '.';

    bless($self, $class);
    return $self;
}

sub id {
    my ($self, $newid) = @_;

    if ($newid) { 
        $self->{id} = $newid;
    }

    return $self->{id};
}

sub get {
    my ($self, $k) = @_;
    unless (defined $self->{$k}) { warn "$k undefined" }
    return $self->{$k};
}

=head1 AUTHOR

Ben Wilber <ben@desync.com>

=head1 LICENSE

This library is free software and may be distributed under the same
terms as Perl itself.

=cut

1;
