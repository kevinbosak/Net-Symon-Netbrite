#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';

use Net::Symon::NetBrite qw(:constants);
use Net::Symon::NetBrite::Zone;

my $sign = Net::Symon::NetBrite->new(
    address => '10.150.3.149',
);

my $hostwidth = 50;

$sign->zones(
    alertnum => Net::Symon::NetBrite::Zone->new(
        rect => [0, 1, 20, 17],
        default_font => 'monospace_16',
        default_color => COLOR_YELLOW,
        initial_text => '{scrolloff}{center}?',
    ),
    alertlabel => Net::Symon::NetBrite::Zone->new(
        rect => [0, 19, 20, 23],
        default_font => 'proportional_5',
        default_color => COLOR_YELLOW,
        initial_text => '{scrolloff}{right}ALRM',
    ),
    line1host => Net::Symon::NetBrite::Zone->new(
        rect => [21, 0, $hostwidth, 11],
        default_font => 'proportional_11',
        default_color => COLOR_GREEN,
        scroll_speed => SCROLL_SLOW,
    ),
    line1 => Net::Symon::NetBrite::Zone->new(
        rect => [$hostwidth + 1, 0, 199, 11],
        default_font => 'proportional_11',
        default_color => COLOR_GREEN,
        scroll_speed => SCROLL_SLOW,
    ),
    line2host => Net::Symon::NetBrite::Zone->new(
        rect => [21, 12, $hostwidth, 17],
        default_font => 'proportional_5',
        default_color => COLOR_GREEN,
        scroll_speed => SCROLL_SLOW,
    ),
    line2 => Net::Symon::NetBrite::Zone->new(
        rect => [$hostwidth + 1, 12, 199, 17],
        default_font => 'proportional_5',
        default_color => COLOR_GREEN,
        scroll_speed => SCROLL_SLOW,
    ),
    line3host => Net::Symon::NetBrite::Zone->new(
        rect => [21, 18, $hostwidth, 23],
        default_font => 'proportional_5',
        default_color => COLOR_GREEN,
        scroll_speed => SCROLL_SLOW,
    ),
    line3 => Net::Symon::NetBrite::Zone->new(
        rect => [$hostwidth + 1, 18, 199, 23],
        default_font => 'proportional_5',
        default_color => COLOR_GREEN,
        scroll_speed => SCROLL_SLOW,
    ),
);

<>;
$sign->message('alertnum', '{scrolloff}{center}{green}0');
$sign->message('alertlabel', '{scrolloff}{yellow}ALRM');
$sign->message('line1host', '.');
$sign->message('line1', '.');
$sign->message('line2host', '.');
$sign->message('line2', '.');
$sign->message('line3host', '.');
$sign->message('line3', '.');
<>;
$sign->message('alertnum', '{scrolloff}{center}{red}1');
$sign->message('alertlabel', '{scrolloff}{red}{blinkon}ALRM', { sound_alarm => 1 });
<>;
$sign->message('line1host', '{scrolloff}{red}pr0.nycx');
$sign->message('line1', '{red}An LP CAM partition is full.');
<>;
$sign->message('line2host', '{scrolloff}{yellow}co1');
$sign->message('line2', '{yellow}Logical link down on e1/8 (412 FSO 2)');
<>;
$sign->message('line3host', '{scrolloff}{yellow}sofy.gvpn');
$sign->message('line3', '{yellow}High CPU for multiple processes.');
<>;
$sign->reboot();

