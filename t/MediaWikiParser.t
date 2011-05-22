#!/usr/bin/perl

use warnings;
use strict;
use 5.10.1;
use Data::Dumper::Simple;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

use lib "/home/kevin/Dropbox/development/modules";

#use Titlecase qw(titlecase isanacronym ucfirstimproved possibleacronym);
use MediaWikiParser qw(tokenise parse rendertext rendertokens customparser flatten mergetokens);

say "You are using version: $MediaWikiParser::VERSION of MediaWikiParser";
 
use Test::More tests => 40 ; #tests => 3;

$MediaWikiParser::debug=0; # make loud
my @stream;

my ($test,$expected);
$test=	qq<==DTS==\n\n\nDTS is very cool. I like it. {{RatingBar}}>;
$expected=	$test; #rendertokens(tokenise($test));

is( rendertext(tokenise($test)) , $expected, "#01 Parsing and re-rendering Integrity Test - first test");

print "\n";
$test=	qq<blah blah's "blah" '''blah''' blah blah blah>;
$expected=	$test; MediaWikiParser::rendertextbar(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "#02 Parsing and re-rendering Integrity Test - apostrophe");

print "\n";
$test=	qq<blah [blahs blah] http://www.ywamkb.net blah blah blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "#03 Parsing and re-rendering Integrity Test - external links");

print "\n";
$test=	qq<blah [[blahs]] [[blah|blah blah [blah blah]]] blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "#04 Parsing and re-rendering Integrity Test - internal links");

print "\n";
$test=	qq<blah blahs {{blah|blah{{blah}}}}blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "#05 Parsing and re-rendering Integrity Test - templates");

print "\n";
$test=	qq<blah blahs <nowiki> [[blah]] blah </nowiki> </ nowiki> blah>;
$expected=	$test; #MediaWikiParser::rendertextbar(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "#06 Parsing and re-rendering Integrity Test - nowiki");

print "\n";
$test=	qq{blah <blah class="" > blah </ blah> blah </blah> blah};
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "#07 Parsing and re-rendering Integrity Test - html");

print "\n";
$test=	qq{blah blah's '''''blah''''' ''blah'' '''blah''' blah};
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "#08 Parsing and re-rendering Integrity Test - html");

$test=	q{ftp://blah.blah __BLAH__ __blah__https://blah.blah.blah http://blah.blah.blah mailto:kevin@example.com}; #correct behaviour is for __blah__http... to render as body text.
print "\n";
$expected=	$test; #MediaWikiParser::rendertextbar(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "#09 Parsing and re-rendering Integrity Test - html");
is( rendertext(parse($test)) , $expected, "#10 Parsing and re-rendering Integrity Test - html");
# note UNKNOWN token warnings are to be EXPECTED as the run on url is supposed to fail...

# tokenising tests

# comments and nowiki
#<!-- [[dts]] -->
##
##*HTMLCOM|IGNORE|HTMLCOM
print "\n";
$test=		qq{<!-- [[dts]] -->};
$expected=	qq{IGNORE}; #HTMLCOM_O|IGNORE|HTMLCOM_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "#11 Tokenising - html comments");

# <nowiki>[[DTS]]<!--showme</nowiki>-->
##[[DTS]]<!--showme-->
##*NOWIKI|IGNORE|NOWIKI|BODYWORD
print "\n";
$test=		qq{<nowiki>[[DTS]]<!--showme</nowiki>-->};
$expected=	qq{IGNORE|NOWIKI|NOWIKI|NOWIKI|NOWIKI|NOWIKI|IGNORE}; #NOWIKI_O|IGNORE|NOWIKI_C|IGNORE}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "#12 Tokenising - NOWIKI comments");

# <nowiki>[[DTS]]<!-- hello --></nowiki></nowiki><nowiki></nowiki>
##[[DTS]]<!-- hello --></nowiki>
##*NOWIKI|IGNORE|NOWIKI|UNKNOWN|NOWIKI|NOWIKI
print "\n";
$test=		qq{<nowiki>[[DTS]]<!-- hello --></nowiki></nowiki><nowiki></nowiki>};
$expected=	qq{IGNORE|NOWIKI|NOWIKI|NOWIKI|NOWIKI|NOWIKI|NOWIKI|NOWIKI|NOWIKI|IGNORE}; #NOWIKI_O|IGNORE|NOWIKI_C|IGNORE|NOWIKI_O|NOWIKI_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "#13 Tokenising - NOWIKI comments");

# <!--[[DTS]]<nowiki>[[DTS]]Insert non-formatted text here</nowiki>-->
#
##*HTMLCOM|IGNORE|HTMLCOM
print "\n";
$test=		qq{<!--[[DTS]]<nowiki>[[DTS]]Insert non-formatted text here</nowiki>-->};
$expected=	qq{IGNORE}; #HTMLCOM_O|IGNORE|HTMLCOM_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "#14 Tokenising - html comments");

# <!--<nowiki>Insert non-formatted text here--></nowiki>
##</nowiki>
##*IGNORE|NOWIKI_C
print "\n";
$test=		qq{<!-- [[dts]] -->};
$expected=	qq{IGNORE}; #HTMLCOM_O|IGNORE|HTMLCOM_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "#15 Tokenising - html comments");

print "\n";
$test=		qq{hello\n\n\nworld\nhello world \n};
$expected=	qq{BODYWORD|NL|BODYWORD|NL|BODYWORD|WS|BODYWORD|WS|NL}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "#16 Tokenising - NEWLINES");

print "\n";
$test=		qq{   hello \n\n world   \n};
$expected=	qq{WS|BODYWORD|WS|NL|PRE_SINGLE|BODYWORD|WS|NL}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "#17 Tokenising - Whitespace");

# === heading ===
##=== heading ===
##*H3|WS|BODYWORD|WS|H3
print "\n";
$test=		qq{=== heading ===};
$expected=	qq{H3|IGNORE|WS|BODYWORD|WS|IGNORE}; #rendertext(tokenise($test));
is( rendertokens(MediaWikiParser::_parseheading(tokenise($test))) , $expected, "#18 Tokenising - balanced headings");

# === heading ==\n== heading ===
##=== heading ==\n== heading ===
##*H2|UNKNOWN|WS|BODYWORD|WS|H2|NL|H2|WS|BODYWORD|WS|H2|UNKNOWN
print "\n";
$test=		qq{=== heading ==\n== heading ===};
$expected=	qq{H2|IGNORE|IGNORE|WS|BODYWORD|WS|IGNORE|NL|H2|IGNORE|WS|BODYWORD|WS|IGNORE|IGNORE}; #rendertext(tokenise($test));
is( rendertokens(MediaWikiParser::_parseheading(tokenise($test))) , $expected, "#19 Tokenising - unbalanced headings");
is( rendertext(MediaWikiParser::_parseheading(tokenise($test))) , $test, "#20 Tokenising - unbalanced headings - rendering fidelity");

#from mediawiki test: 
# ===hello
# world (body text)===
# 
# ===level 3? (=level2)==
# 
# ==level2? (level2=)===

# === heading\n ===
##=== heading\n ===
##*H3|WS|BODYWORD|NL|WS|UNKNOWN
print "\n";
$test=		qq{=== heading\n ===};
$expected=	qq{IGNORE|WS|BODYWORD|NL|PRE_SINGLE|IGNORE}; #rendertext(tokenise($test));
is( rendertokens(MediaWikiParser::_parseheading(tokenise($test))) , $expected, "#21 Tokenising - balanced headings");
#ignore warning for unrecognised token UNKNOWN here.

# [[DTS
#]]
##[[DTS
##]]
##*ILINK_O|BODYWORD|NL|ILINK_C
say "Using SIMPLEPARSER...\n";
$test=		qq<==hello{{[[dts]]world  {{hello}}}} }}==>;
$expected=	qq{H2|IGNORE|BODYTEXT|IGNORE|BODYTEXT|IGNORE};
is( rendertokens(parse($test)) , $expected, "#22 Tokenising - templates and optimising and simplifying");
print "\n";
is( rendertext(parse($test)) , $test, "#23 Tokenising and rendering fidelity");

print "\n";
$test=		qq<[[hello]] [[this is a link|oh yes it is]] ]] [[\n]][[hello|world|hello]]>;
$expected=	qq{IGNORE|BODYTEXT|IGNORE|BODYTEXT|IGNORE|BODYTEXT|IGNORE|BODYTEXT|IGNORE};
is( rendertokens(parse($test)) , $expected, "Tokenising - internal links");
print "\n";
is( rendertext(parse($test)) , $test, "Tokenising - internal links rendering fidelity");
#rendertokens( MediaWikiParser::_parseilink_simple ( tokenise($test)));

print "\n";
$test=		qq<outside table\n{|    \n| in a table \n| ignore this\n{| \n|another table\n|}\nback infirst \n|}\nout of table ignore |}>;
$expected=	qq{BODYTEXT|IGNORE|BODYTEXT|IGNORE};
is( rendertokens(parse($test)) , $expected, "Tokenising - table - simple");
print "\n";
is( rendertext(parse($test)) , $test, "Tokenising - table - simple - rendering fidelity");

print "\n";
$test=		qq{http://www.ywambrussels.be [http://www.ywambrussels.be] [http://www.ywambrussels.be A great site!]};
$expected=	qq{URL|WS|ELINK_O|URL|ELINK_C|WS|ELINK_O|URL|WS|BODYWORD|WS|BODYWORD|WS|BODYWORD|EXCLAMATION|ELINK_C};
is( rendertokens( tokenise($test)), $expected, "External link and URL tokeniser");
print "\n";
is( rendertext( tokenise($test)), $test, "External link and URL tokeniser - rendering fidelity");
#print "\n";
#say rendertokens( parse($test));
### TODO more url tests here...

print "\n";
$test=		q{mailto:kevin@example.com [mailto://kevin@example.com] [mailto://kevin@example.com?subject=hello%20world! A great site!]};
$expected=	qq{MAILTO|WS|ELINK_O|MAILTO|ELINK_C|WS|ELINK_O|MAILTO|WS|BODYWORD|WS|BODYWORD|WS|BODYWORD|EXCLAMATION|ELINK_C};
is( rendertokens( tokenise($test)), $expected, "External link and mailto tokeniser");
print "\n";
is( rendertext( parse($test)), $test, "External link and mailto tokeniser - rendering fidelity");

$test=		q<{{http://kevin.example.com}} this is bodytext>;
$expected=	qq{TEMPL_O|URL|TEMPL_C|WS|BODYWORD|WS|BODYWORD|WS|BODYWORD};
is( rendertokens( tokenise($test)), $expected, "URL inside a template test");
is( rendertokens( parse($test)), "IGNORE|BODYTEXT", "URL inside a template test part2");
print "\n";

print "========================================\n";
#now for something more interesting - test of a heading parser...

my %o1 = (
    IGNORE 	=> 'IGNORE', #might always need this? 
    UNKNOWN	=> 'BODYTEXT', #might always need this? 
    TEMPLATE    => 'IGNORE',
    BODYWORD 	=> 'BODYTEXT',    
    BAR 	=> 'BODYTEXT',        
    POINT 	=> 'BODYTEXT',       
    COLON 	=> 'BODYTEXT',       
    SEMICOLON 	=> 'BODYTEXT',   
    EXCLAMATION => 'BODYTEXT', 
    NL 		=> 'BODYTEXT',          
    WS 		=> 'BODYTEXT', 	   
    APOSTROPHY 	=> 'BODYTEXT',  
  
    H1		=> 'H1',
    H2		=> 'H2',
    H3		=> 'H3',
    H4		=> 'H4',
    H5		=> 'H5',
    H6		=> 'H6',

	MAGICWORD 	=> 'IGNORE',
	PRE_O 		=> 'IGNORE',      
	PRE_C 		=> 'IGNORE',      
	HTML_O 		=> 'IGNORE',      
	HTML_C 		=> 'IGNORE',  
	HTML_BODY	=> 'IGNORE',
	HTML_SINGLE	=> 'IGNORE', 

# may not want these but here for now - ignored in pass2
    ELINK_O	=> 'ELINK',     
    ELINK_C 	=> 'ELINK',  
    ELINKMAILTO	=> 'ELINKMAIILTO',
    ELINKCOMMENT=> 'ELINKCOMMENT',  	# for now otherwise ELINK
    ILINK_O 	=> 'ILINK',     
    ILINK_C 	=> 'ILINK',   
    ILINK_PAGE	=> 'ILINK',		# for now
    ILINK_COMMENT=> 'BODYTEXT',		# for now

);
my %o2 = (
    #
    # PASS2...
    IGNORE 	=> 'IGNORE', 		# needed for pass2
    UNKNOWN 	=> 'IGNORE', 

    BODYTEXT	=> 'BODYTEXT', 		# needed for pass 2
    HTML 	=> 'IGNORE',
    TEMPLATE	=> 'IGNORE',
    ILINK 	=> 'IGNORE',
    ELINK 	=> 'IGNORE',
    TABLE 	=> 'IGNORE',

    H1		=> 'H1',
    H2		=> 'H2',
    H3		=> 'H3',
    H4		=> 'H4',
    H5		=> 'H5',
    H6		=> 'H6',
    HTMLCOM 	=> 'IGNORE',
    NOWIKI 	=> 'IGNORE',
    URL 	=> 'IGNORE',
);

$test=		qq<==hello {{ignore this}} world, how are you?==>;
$expected=	qq<H2|IGNORE|BODYTEXT|IGNORE|BODYTEXT|IGNORE>;
@stream = 	customparser($test, \%o1, \%o2);
	is	(rendertokens(@stream), $expected, "#32 Testing customparser for headings...");

$test=		qq<This is some '''bold''' text\n== hello horld ==\n== hello '''bold''' world==>;
$expected=	qq<BODYTEXT|H2|IGNORE|BODYTEXT|IGNORE|BODYTEXT|H2|IGNORE|BODYTEXT|IGNORE>;
@stream = 	customparser($test, \%o1, \%o2);
	is	(rendertokens(@stream), $expected, "#33 Testing customparser for headings 2...");

$test=		qq<=l1=\n==l2==\n===l3===\n====l4====\n=====l5=====\n======l6======>;
$expected=	qq<H1|IGNORE|BODYTEXT|IGNORE|BODYTEXT|H2|IGNORE|BODYTEXT|IGNORE|BODYTEXT|H3|IGNORE|BODYTEXT|IGNORE|BODYTEXT|H4|IGNORE|BODYTEXT|IGNORE|BODYTEXT|H5|IGNORE|BODYTEXT|IGNORE|BODYTEXT|H6|IGNORE|BODYTEXT|IGNORE>;
@stream = 	customparser($test, \%o1, \%o2);
	is	(rendertokens(@stream), $expected, "#34 Testing customparser for all headings...");
# 	say MediaWikiParser::rendertokensbartext(@stream);

# $test=		qq{Arana-Quirez, P., Isan-Chan, D., Clarke, S., et al, “Lausanne Occasional Paper 24: <nowiki>Cooperating in World Evangelization: A Handbook on Church/Para-Church Relationships.” <</nowiki>[http://www.lausanne.org/documents.html http://www.lausanne.org/documents.html]> (27<sup>th</sup> September, 2007).};
# @stream = 	customparser($test, \%o1, \%o2);
# 	say MediaWikiParser::rendertokensbartext(@stream);
# not a test above?


say "\nParsing howtowriteinwiki.dat";
open FILE, "<howtowriteinwiki.dat";
$test = do { local $/; <FILE> };
@stream = customparser($test, \%o1, \%o2); 
my @stream2 =@stream;

my $iter = MediaWikiParser::walkstream(\@stream);
my $items;
while (my $tok = $iter->()) {
    $items++; #say "walkstream: ",$tok->[0];
}
say "Items: $items";
is(@stream,@stream2,"compare walkstream stacks to see if stack is untouched");

# say MediaWikiParser::rendertokensbartext( parseheadingtext( @stream ) );

$test=		qq<== hello __NOTOC__ world ==\n== hello '''bold''' world==>;
$expected=	qq<H2|IGNORE|BODYTEXT|IGNORE|BODYTEXT|H2|IGNORE|BODYTEXT|IGNORE>;
@stream = 	customparser($test, \%o1, \%o2);
	is	(rendertokens(@stream), $expected, "#34 Testing customparser for headings 3...");
# say rendertokens  MediaWikiParser::flatten( @stream ) ;
# say MediaWikiParser::rendertokensbartext( @stream );

	is	(rendertext(flatten(@stream)), $test, "#35 Testing customparser and flattern sub");
	is	(rendertext(parseheadingtext(@stream)), $test, "#36 Rendering integrity checking parseheadingtext sub");

sub parseheadingtext {
    my (@stream) = @_ ;
#     warn Dumper @stream;
    # run a custom parser on text... output in stack
    # convert nested heading bodytext to headingtext
    # flatten
    # return bit by bit
    for (0..@stream-1) {
# 	say $_;
	my $tok= $stream[$_];
# 	say $tok->[0],$tok->[1];
	if ($tok->[0] =~ /H\d/) {
	    map {  $_->[0] =~ s/BODYTEXT/HEADINGTEXT/ } @{ $tok->[1] };
	    $tok->[0] = 'IGNORE';     # don't want heading number anymore 
	}
	$tok->[0] =~ s/BODYTEXT/IGNORE/ ; # no body text either outside of headings
    }
#     warn Dumper @stream;
    @stream = mergetokens flatten @stream;
    
#     warn Dumper @stream;
    return @stream;
}

sub make_parseheadingtext_iterator {
    my (@stream) = parseheadingtext( @_ ) ; # process and flatten stack
    return sub {
	return undef if !@stream; # if nothing more return undef
	return shift @stream; # otherwise return a token and mergetokens stack
	}
}



# use Titlecase qw(titlecase);
# 
# my $iterator=make_parseheadingtext_iterator ( @stream2 );
# my $correct;
# while ( my $tok = $iterator->() ) {
#     if ($tok->[0] eq 'HEADINGTEXT') { $correct = titlecase( $tok->[1] );
#     say "|".$tok->[1]."|";
#     say "    corrected to |".$correct."|" if $tok->[1] ne $correct;
#     }
# }