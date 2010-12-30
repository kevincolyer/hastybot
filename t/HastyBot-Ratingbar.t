#!/usr/bin/perl
#

use warnings;
use strict;
use 5.10.0;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";
#use Test::More qw( no_plan ); #tests => 3;

use HastyBot qw(addtopage getpagelist getnextpage nextpage getpage %opts);

use Titlecase qw(titlecase);

say "You are using version: $HastyBot::VERSION of HastyBot";
 

addtopage(qr/\{\{RatingBar\}\}/, "{{RatingBar}}\n","","Adding {{RatingBar}} to page");


#$opts{debug}=1;
#$opts{simulate}=1;
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



sub snippet {
    my $text = shift;
    my $len = shift || 72;
    $text = substr($text,0,$len);
    $text =~ s/\n//g;
    $text =~ s/\{\{.*?\}\}//g;
    return "... ".$text." ...";
}