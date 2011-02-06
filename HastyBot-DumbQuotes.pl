#!/usr/bin/perl

use warnings;
use strict;
use 5.10.0;
use Data::Dumper::Simple;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

use lib "/home/kevin/Dropbox/development/modules";


use HastyBotParsers qw(parseheadingtext);
$MediaWikiParser::debug=0; # make loud
use Titlecase qw(titlecase);
say "Starting up...";
use HastyBot qw(addtopage getpagelist getnextpage nextpage getpage %opts savepage markpageseen getallpages);

#$opts{debug}=1;
# $opts{simulate}=1;
#$opts{verbose}=1;
my $numedits=0;
my $index=200;
my $limiter=$index+2000;
$opts{whatpages}='all';
my @allpages= getallpages();#re-loads the list
say "Processing pages...";
while (my $edit = getpage($allpages[$index])) {
    my $replace=$edit;
    my $page=$allpages[$index];
    say "\n$index: [[$page]]";
    $index++;

    $replace =~ tr/“”‘’/""''/; # say "Smart Quotes!\n$replace" if $replace ne $edit;
    $replace =~ s/–/--/g;
    $replace =~ s/—/---/g;
    $replace =~ s/…/.../g;

    # save page - $replace holds MODIFIED text
    
    if ($edit ne $replace) {
	my $comment = "Translated all smart quotes and N and M dashes and Elipsis into dumb ascii";
	say $comment;
	savepage($page,$replace,$comment);
	$numedits++;
    } else { markpageseen($page); };
    last if $index==$limiter;
}

say "$numedits page(s) modified";