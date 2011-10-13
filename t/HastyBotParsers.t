#!/usr/bin/perl

use warnings;
use strict;
use 5.10.1;
#use Data::Dumper::Simple;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

use lib "/home/kevin/Dropbox/development/modules";


use HastyBotParsers qw(parseheadingtext);

use Titlecase qw(titlecase);
#use Test::More qw( no_plan ); #tests => 3;

$MediaWikiParser::debug=0; # make loud

# my ($test,$expected);
# say "\nParsing howtowriteinwiki.dat";
# open FILE, "<howtowriteinwiki.dat";
# $test = do { local $/; <FILE> };
# 
# my @stream=parseheadingtext ( $test );
# my @stream2=@stream;
# my $correct;
# my $h="";
# my @headings= (0,0,0,0,0,0,0);
# while ( my $tok = shift @stream ) {
#     if ($tok->[0] =~ m/\d/) { $h=$tok->[0]; $headings[$h]++ };
#     if ($tok->[0] eq 'HEADINGTEXT') { $correct = titlecase( $tok->[1] );
#     say "|".$tok->[1]."| is a $h";
#     say "   --->  corrected to |".$correct."|" if $tok->[1] ne $correct;
#     }
# #     if ($tok eq 'HEADINGTEXT') { $correct = titlecase( $tick );
# #     say "|".$tick."|";
# #     say "   --->  corrected to |".$correct."|" if $tick ne $correct;
# #     }
# }
# say "Summary of Headings";
# say "$_ = ".scalar $headings[$_] for 1..$#headings;

##################try on ywamkb...#####################

use HastyBot qw(addtopage getpagelist getnextpage nextpage getpage %opts savepage markpageseen);

say "You are using version: $HastyBot::VERSION of HastyBot";
 
#$opts{debug}=1;
$opts{simulate}=1;
#$opts{verbose}=1;

my $throttle=0;
my $limiter=80;
$opts{whatpages}='all';
 getpagelist();#re-loads the list

while (my ($page,$edit) = getnextpage("ignore seen")) {
    #$page="YWAM England Leadership Appraisal Pack"; $edit = getpage($page);
    say "$throttle: [[$page]]";
    $throttle++;
    my @stream=	parseheadingtext ( $edit );
    #my @stream2=@stream;
    my $replace="";
    my $h=	"";
    my $num=	0;
    my @headings= (0,0,0,0,0,0,0);
    # process page contents
    while ( my $tok = shift @stream ) {
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
    } else { markpageseen($page); };
    last if $throttle==$limiter;
}