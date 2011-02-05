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
    my @stack=	parseheadingtext ( $edit );
    my $replace="";
    my $h=	"";
    my $num=	0;
    my @headings= (0,0,0,0,0,0,0);
    if (substr($page,0,3) =~ m/fr|nl|de/i) {
	say "Non-English language page. Skipping...";
	last if $index==$limiter;
	next;
    }
    # process page contents
    while ( my $tok = shift @stack ) {
	my $text=$tok->[1];
	if ($tok->[0] =~ m/\d/) { $h=$tok->[0]; $headings[$h]++ };
	if ($tok->[0] eq 'HEADINGTEXT') { $text = titlecase( $text );
	if (substr($text,0,1)  ne " ") { $text = " ".$text }; #tidy headings to have space either side
	if (substr($text,-1,1) ne " ") { $text = $text." " }; # the end...
	#say "|".$tok->[1]."| is a $h";
	if ($tok->[1] ne $text) { say "   --->  correction |".$text."|"; $num++ };
	}
	$replace.=$text; # rebuild the text of the page
    }
    #say "Summary of Headings for [[$page]]";
    #say "$_ = ".scalar $headings[$_] for 1..$#headings;
    # save page
    
    if ($edit ne $replace) {
	my $comment = "Corrected capitalisation of $num heading(s)";
	say $comment;
	savepage($page,$replace,$comment);
	$numedits++;
    } else { markpageseen($page); };
    last if $index==$limiter;
}

say "$numedits page(s) modified";