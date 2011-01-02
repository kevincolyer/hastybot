#!/usr/bin/perl

use warnings;
use strict;
use 5.10.0;
use Data::Dumper::Simple;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

#use Titlecase qw(titlecase isanacronym ucfirstimproved possibleacronym);
use MediaWikiParser qw(tokenise parse rendertext rendertokens);

say "You are using version: $MediaWikiParser::VERSION of MediaWikiParser";
 
use Test::More qw( no_plan ); #tests => 3;

my ($test,$expected);
$test=	qq<==DTS==\n\n\nDTS is very cool. I like it. {{RatingBar}}>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - first test");

$test=	qq<blah blah's "blah" '''blah''' blah blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - apostrophe");

$test=	qq<blah [blahs blah] http://www.ywamkb.net blah blah blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - external links");

$test=	qq<blah [[blahs]] [[blah|blah blah [blah blah]]] blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - internal links");

$test=	qq<blah blahs {{blah|blah{{blah}}}}blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - templates");

$test=	qq<blah blahs <nowiki> [[blah]] blah </nowiki> </ nowiki> blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - nowiki");

$test=	qq{blah <blah class="" > blah </ blah> blah </blah> blah};
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - html");

$test=	qq{blah blah's '''''blah''''' ''blah'' '''blah''' blah};
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - html");

$test=	qq{ftp://blah.blah __BLAH__ __blah__https://blah.blah.blah http://blah.blah.blah mailto:kevin\@example.com}; #correct behaviour is for __blah__http... to render as body text.
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - html");
is( rendertext(parse($test)) , $expected, "Parsing and re-rendering Integrity Test - html");

# tokenising tests

# comments and nowiki
#<!-- [[dts]] -->
##
##*HTMLCOM|IGNORE|HTMLCOM
$test=		qq{<!-- [[dts]] -->};
$expected=	qq{HTMLCOM_O|IGNORE|HTMLCOM_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - html comments");

# <nowiki>[[DTS]]<!--showme</nowiki>-->
##[[DTS]]<!--showme-->
##*NOWIKI|IGNORE|NOWIKI|BODYWORD
$test=		qq{<nowiki>[[DTS]]<!--showme</nowiki>-->};
$expected=	qq{NOWIKI_O|IGNORE|NOWIKI_C|UNKNOWN}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - NOWIKI comments");

# <nowiki>[[DTS]]<!-- hello --></nowiki></nowiki><nowiki></nowiki>
##[[DTS]]<!-- hello --></nowiki>
##*NOWIKI|IGNORE|NOWIKI|UNKNOWN|NOWIKI|NOWIKI
$test=		qq{<nowiki>[[DTS]]<!-- hello --></nowiki></nowiki><nowiki></nowiki>};
$expected=	qq{NOWIKI_O|IGNORE|NOWIKI_C|UNKNOWN|NOWIKI_O|NOWIKI_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - NOWIKI comments");

# <!--[[DTS]]<nowiki>[[DTS]]Insert non-formatted text here</nowiki>-->
#
##*HTMLCOM|IGNORE|HTMLCOM
$test=		qq{<!--[[DTS]]<nowiki>[[DTS]]Insert non-formatted text here</nowiki>-->};
$expected=	qq{HTMLCOM_O|IGNORE|HTMLCOM_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - html comments");

# <!--<nowiki>Insert non-formatted text here--></nowiki>
##</nowiki>
##*IGNORE|NOWIKI_C
$test=		qq{<!-- [[dts]] -->};
$expected=	qq{HTMLCOM_O|IGNORE|HTMLCOM_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - html comments");

$test=		qq{hello\n\n\nworld\nhello world \n};
$expected=	qq{BODYWORD|NL|BODYWORD|NL|BODYWORD|WS|BODYWORD|WS|NL}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - NEWLINES");

$test=		qq{   hello \n\n world   \n};
$expected=	qq{WS|BODYWORD|WS|NL|WS|BODYWORD|WS|NL}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - Whitespace");

# === heading ===
##=== heading ===
##*H3|WS|BODYWORD|WS|H3
$test=		qq{=== heading ===};
$expected=	qq{H3|WS|BODYWORD|WS|H3}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - balanced headings");

# === heading ==\n== heading ===
##=== heading ==\n== heading ===
##*H2|UNKNOWN|WS|BODYWORD|WS|H2|NL|H2|WS|BODYWORD|WS|H2|UNKNOWN
$test=		qq{=== heading ==\n== heading ===};
$expected=	qq{H2|UNKNOWN|WS|BODYWORD|WS|H2|NL|H2|WS|BODYWORD|WS|H2|UNKNOWN}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - unbalanced headings");

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
$test=		qq{=== heading\n ===};
$expected=	qq{H3|WS|BODYWORD|NL|WS|UNKNOWN}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - balanced headings");
# [[DTS
#]]
##[[DTS
##]]
##*ILINK_O|BODYWORD|NL|ILINK_C
$test=		qq<hello{{[[dts]]world  {{hello}}}} }}>;
$expected=	qq{BODYTEXT|IGNORE|BODYTEXT|IGNORE};
is( rendertokens(parse($test)) , $expected, "Tokenising - templates and optimising and simplifying");
is( rendertext(parse($test)) , $test, "Tokenising and rendering fidelity - templates and optimising and simplifying");