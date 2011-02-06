#!/usr/bin/perl

use warnings;
use strict;
use 5.10.0;
use Data::Dumper::Simple;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

use lib "/home/kevin/Dropbox/development/modules";


use HastyBotParsers qw(parsebadlinks);
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
my $limiter=$index+20;
#$opts{whatpages}='all';
# my @allpages= getallpages();#re-loads the listo
my @allpages= qw(Sandbox); # YWAM_Websites_List # only one page please!

use LWP; # Loads all important LWP classes
my ($d,$m,$y) = (localtime)[3,4,5] ;
my $dmy = sprintf ('%d-%d-%d', $d, $m+1, $y+1900); 



say "Processing pages...";
while (my $edit = getpage($allpages[$index])) {
    my $page=$allpages[$index];
    say "\n$index: [[$page]]";
    $index++;
    my @stack=		parsebadlinks ( $edit );
    my $replace=	"";
    my $num	=	0;
    my $numalive=	0;
    # process page contents
    while ( my $tok = shift @stack ) {
	my $text=$tok->[1];
	my $url="";
	if ($tok->[0] eq 'BAREURL') { say "got a bare url! ", $url=$tok->[1];};
	if ($tok->[0] eq 'ELINKURL'){ say "got a E-LINK! ",   $url=$tok->[1];};
	if ($url ne "") { 
	    my $browser = LWP::UserAgent->new;
	    my $response = $browser->get( $url );
	    if ($response->is_success) {say "Page is alive!";}
		else { say "Can't get $url -- ", $response->status_line; $num++;
			$text="{{badlinks|$url|1|$dmy}}";  }
	}
	say "Token ".$tok->[0]." is |$text|";
	$replace.=$text;
    }
    #say "Summary of Headings for [[$page]]";
    #say "$_ = ".scalar $headings[$_] for 1..$#headings;
    # save page
    
    if ($edit ne $replace) {
	my $comment = "Badlinks marked: $num. Badlinks come back to life and unmarked $numalive.";
	say $comment;
# 	say $replace;
	savepage($page,$replace,$comment);
	$numedits++;
    } else { markpageseen($page); };
    last if $index==$limiter;
}

say "$numedits page(s) modified";