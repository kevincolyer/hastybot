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

#say "You are using version: $HastyBot::VERSION of HastyBot";
 
#$opts{debug}=1;
#$opts{simulate}=1;
#$opts{verbose}=1;
my $numedits=0;
my $index=0;
my $limiter=$index+2000;
$opts{whatpages}='all';
my @allpages= getallpages();#re-loads the list
say "Processing pages...";
while (my $edit = getpage($allpages[$index])) {
    my $page=$allpages[$index];
#     my $page="Continuous Improvement"; $edit = getpage($page);
    say "\n$index: [[$page]]";
    $index++;
    if ($edit !~ m/^=\s/gm) {next if $limiter>$index;}
    say "Heading of level 1 possibly detected. Parsing...";
    my @stack=	parseheadingtext ( $edit, 1 ); # passing zero omits flattening stage...
    my $replace=$edit;
    my $h=	"";
    my $num=	0;
    my @headings= (0,0,0,0,0,0,0);
    my @savestack=@stack;
    # process page contents
    while ( my $tok = shift @stack ) {
	my $text=$tok->[1];
	if ($tok->[0] =~ m/\d/) { $h=$tok->[0]; $headings[$h]++ };
    }
    say "Summary of Headings for [[$page]]";
    say "$_ = ".scalar $headings[$_] for 1..$#headings;
    
    if ($headings[1]) {
	say "Heading of level 1 detected - starting correction process";
	if ($headings[6]) {
	    say "Heading level 6 exists - can't demote any headings - MANUAL INTEVERVENTION NEEDED";
	    next;
	}
	@stack=@savestack;
	for (0..@stack-1) {
    # 	say $_;
	    my $tok= $stack[$_];
	    #say $tok->[0],$tok->[1];
	    if ($tok->[0] =~ /\d/) {
		$tok->[1]->[0]->[1]  .= "="; 
		$tok->[1]->[-1]->[1] .= "=";
		$num++;
	    }
	}
    $replace=MediaWikiParser::rendertext(MediaWikiParser::flatten(@stack));
    #say $replace;
    }
    # save page
    
    if ($edit ne $replace) {
	my $comment = "Shifted heading levels from 1 -> 2 and demoted all headings by 1 to match. $num heading(s)";
	say $comment;
	savepage($page,$replace,$comment);
	$numedits++;
    } else { markpageseen($page); };
    last if $index==$limiter;
}

say "$numedits page(s) modified";