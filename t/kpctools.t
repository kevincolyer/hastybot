#!/usr/bin/perl
#
# ~/Dropbox/Development/HastyBot/t/modules.t
#
#  Test that all the Perl modules we require are available.
#
use warnings;
use strict;
use 5.10.0;
use Test::More qw( no_plan ); #tests => 3;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

use Kpctools qw(commify snippet);

say "You are using version: $Kpctools::VERSION";
 
my $test=1000000;
my $expected=	qq{1,000,000};
is( commify($test), $expected, "Integer test" ); #1

$test="hello\nworld";
$expected="... helloworld ...";
is( snippet($test), $expected, "Snippet test" ); #2