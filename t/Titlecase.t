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
use Data::Dumper::Simple;
use utf8;

use lib "/home/kevin/Dropbox/development/modules";

binmode STDOUT, ":encoding(UTF-8)";
use Titlecase qw(titlecase isanacronym ucfirstimproved possibleacronym);

say "You are using version: $Titlecase::VERSION of Titlecase.pm";
 
my $test=	qq{THIS IS ALL IN UPPERCASE AND SHOULD BE LOWERCASE};
my $expected=	qq{This is All in Uppercase and Should Be Lowercase};
is( titlecase($test), $expected, "Simple test" ); #1

$test=		qq{"I think this is the 1st, 2nD, 3rD, 4th and 256th case" Dr. house};
$expected=	qq{"I Think This is the 1st, 2nd, 3rd, 4th and 256th Case" Dr. House};
is( titlecase($test), $expected, "Ordinals test" ); #2

$test=		qq{==i am a good heading==};
$expected=	qq{==I am a Good Heading==};
is( titlecase($test), $expected, "Heading test" ); #3

$test=		qq{a first letter is always a capital};
$expected=	qq{A First Letter is Always a Capital};
is( titlecase($test), $expected, "First capital test" ); #4

$test=		qq{An annoying AMSTERDAM issue};
$expected=	qq{An Annoying Amsterdam Issue};
is( titlecase($test), $expected, "Embedded little words test" ); #5

$test=		qq{An 'annoying' 'AMSTERDAM' issue};
$expected=	qq{An 'Annoying' 'Amsterdam' Issue};
is( titlecase($test), $expected, "Messy punctuation test" ); #6

$test=		qq{an as at but by en for if in is it the to vs vs};
$expected=	qq{An as at but by en for if in is it the to vs vs};
is( titlecase($test), $expected, "Ignore little words test" ); #7

$test=		qq{YWAM BRUssels DTS - it's the BEST of the dts'S: All YWAMers should do one.};
$expected=	qq{YWAM Brussels DTS - It's the Best of the DTS's: All YWAMers Should Do One.}; # can't handle Dts's yet nor probably should!
is(titlecase($test), $expected, "Acronym test"); #8

$test=		qq{==ywam BRUssels dts: it's the BEST of the dts'S: All "YWAMers" should do one.==};
$expected=	qq{==YWAM Brussels DTS: It's the Best of the DTS's: All "YWAMers" Should Do One.==}; # can't handle Dts's yet nor probably should!
is(titlecase($test), $expected, "Acronym with punctuation test"); #9

$test=		qq{==[[Fundraising for YWAMERS]]==};
$expected=	qq{==[[Fundraising for YWAMERS]]==}; # should ignore things in double link brackets.
is(titlecase($test), $expected, "Internal links test"); #10

$test=		qq{==[http://www.ywamkb.net YWAM's KnowledgeBase]==};
$expected=	qq{==[http://www.ywamkb.net YWAM's KnowledgeBase]==}; # should ignore things in single link brackets.
is(titlecase($test), $expected, "External links test"); #11

$test=		qq{==http://www.ywamkb.net YWAM's knowledgebase==};
$expected=	qq{==http://www.ywamkb.net YWAM's KnowledgeBase==}; # should ignore naked links
is(titlecase($test), $expected, "Bare External links test"); #12

use Tie::File::AsHash;

tie my %possacro, 'Tie::File::AsHash', 'PossibleAcronym.conf', split => ':'
        or die "Problem tying %possacro: $!";
my %newacro=possibleacronym();

for my $key (sort keys %newacro) {
   say "$key -> ",$newacro{$key};
   $possacro{$key}='seen';
   };
#warn Dumper %possacro;
untie %possacro;