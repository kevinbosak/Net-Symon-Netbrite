#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 11;

BEGIN {
    use_ok('Net::Symon::NetBrite');
    use_ok('Net::Symon::NetBrite::Zone');
}

can_ok('Net::Symon::NetBrite', ('new'));

my $step = 1;

my $sign = Net::Symon::NetBrite->new(
    callback => sub {
        my $pkt = shift;
        #printf(STDERR "%d [%s]\n", $step, unpack('H*', $pkt));

        if ($step == 1) {
            ok($pkt eq pack('H*', '1616015c00100100001001001001100100c81001000010011004000f000e02100100000a0a0d02000ce8030bfe0ae803090e0810040710010610010500001004dc0710040a131521000300002f02ff10103a1001100100030e00020000000000030000000000000000fe7e000200100100000010040000000000000000fe7e002e170f7b04'), 'sign init');
        } elsif ($step == 2) {
            ok($pkt eq pack('H*', '1616011e00020000100100030800100102000c00000010010000000000000000fe000074657374206d6573736167651790ab04'), 'sign msg');
        } elsif ($step == 3) {
            ok($pkt eq pack('H*', '16160102000300001001001001100100c81001000010010f0017643104'), 'sign reboot');
        }

        $step++;
    },
);

isa_ok($sign, 'Net::Symon::NetBrite');

can_ok('Net::Symon::NetBrite::Zone', ('new'));

my $zone = Net::Symon::NetBrite::Zone->new(
    rect => [0, 0, 10, 10],
);

isa_ok($zone, 'Net::Symon::NetBrite::Zone');

can_ok($zone, ('id', 'get'));

can_ok($sign, ('connect', 'tx', 'zones', 'message', 'reboot'));

$sign->zones( test => $zone );
$sign->message('test', 'test message');
$sign->reboot();

1;
