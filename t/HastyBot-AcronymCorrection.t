#!/usr/bin/perl
#

use warnings;
use strict;
use 5.10.0;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";
#use Test::More qw( no_plan ); #tests => 3;

use HastyBot qw(addtopage getpagelist getnextpage nextpage getpage %opts);
use Titlecase qw(titlecase isanacronym possibleacronym);
use Kpctools qw(snippet);

say "You are using version: $HastyBot::VERSION of HastyBot";
#$opts{debug}=1;
$opts{simulate}=1;
#$opts{verbose}=1;

getpagelist();#re-loads the list


while (my ($page,$edit) = getnextpage("ignore seen")) {
    say "[[$page]]";
    foreach my $line (split /\n/,  $edit) {
	if ($line =~ m/^=+/) {
	    say "$line\n",titlecase($line)
	}
    }
}


#  [[ [ {{ {{{ <nowiki> </nowiki> }}} ] ]] http://www.ywamkb.net - really requires parsing mailto:// ftp:// https:// <!-- -->

# [[ ]]
# [ ]
# {{ }}
# {{{ }}}
# <nowiki> </nowiki>
#{| |}
# http etc...