#!/usr/bin/perl
#

use warnings;
use strict;
use 5.10.1;
use Test::More qw( no_plan ); #tests => 3;

use HastyBot qw(commify);

say "You are using version: $Kpctools::VERSION of HastyBot.pm";
 
my $test=1000000;
my $expected=	qq{1,000,000};
is( commify($test), $expected, "Integer test" ); #1
