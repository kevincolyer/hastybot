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

print "\n";
$test=	qq<blah blah's "blah" '''blah''' blah blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - apostrophe");

print "\n";
$test=	qq<blah [blahs blah] http://www.ywamkb.net blah blah blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - external links");

print "\n";
$test=	qq<blah [[blahs]] [[blah|blah blah [blah blah]]] blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - internal links");

print "\n";
$test=	qq<blah blahs {{blah|blah{{blah}}}}blah blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - templates");

print "\n";
$test=	qq<blah blahs <nowiki> [[blah]] blah </nowiki> </ nowiki> blah>;
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - nowiki");

print "\n";
$test=	qq{blah <blah class="" > blah </ blah> blah </blah> blah};
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - html");

print "\n";
$test=	qq{blah blah's '''''blah''''' ''blah'' '''blah''' blah};
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - html");

$test=	qq{ftp://blah.blah __BLAH__ __blah__https://blah.blah.blah http://blah.blah.blah mailto:kevin\@example.com}; #correct behaviour is for __blah__http... to render as body text.
print "\n";
$expected=	$test; #rendertokens(tokenise($test));
is( rendertext(tokenise($test)) , $expected, "Parsing and re-rendering Integrity Test - html");
is( rendertext(parse($test)) , $expected, "Parsing and re-rendering Integrity Test - html");

# tokenising tests

# comments and nowiki
#<!-- [[dts]] -->
##
##*HTMLCOM|IGNORE|HTMLCOM
print "\n";
$test=		qq{<!-- [[dts]] -->};
$expected=	qq{HTMLCOM_O|IGNORE|HTMLCOM_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - html comments");

# <nowiki>[[DTS]]<!--showme</nowiki>-->
##[[DTS]]<!--showme-->
##*NOWIKI|IGNORE|NOWIKI|BODYWORD
print "\n";
$test=		qq{<nowiki>[[DTS]]<!--showme</nowiki>-->};
$expected=	qq{NOWIKI_O|IGNORE|NOWIKI_C|UNKNOWN}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - NOWIKI comments");

# <nowiki>[[DTS]]<!-- hello --></nowiki></nowiki><nowiki></nowiki>
##[[DTS]]<!-- hello --></nowiki>
##*NOWIKI|IGNORE|NOWIKI|UNKNOWN|NOWIKI|NOWIKI
print "\n";
$test=		qq{<nowiki>[[DTS]]<!-- hello --></nowiki></nowiki><nowiki></nowiki>};
$expected=	qq{NOWIKI_O|IGNORE|NOWIKI_C|UNKNOWN|NOWIKI_O|NOWIKI_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - NOWIKI comments");

# <!--[[DTS]]<nowiki>[[DTS]]Insert non-formatted text here</nowiki>-->
#
##*HTMLCOM|IGNORE|HTMLCOM
print "\n";
$test=		qq{<!--[[DTS]]<nowiki>[[DTS]]Insert non-formatted text here</nowiki>-->};
$expected=	qq{HTMLCOM_O|IGNORE|HTMLCOM_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - html comments");

# <!--<nowiki>Insert non-formatted text here--></nowiki>
##</nowiki>
##*IGNORE|NOWIKI_C
print "\n";
$test=		qq{<!-- [[dts]] -->};
$expected=	qq{HTMLCOM_O|IGNORE|HTMLCOM_C}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - html comments");

print "\n";
$test=		qq{hello\n\n\nworld\nhello world \n};
$expected=	qq{BODYWORD|NL|BODYWORD|NL|BODYWORD|WS|BODYWORD|WS|NL}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - NEWLINES");

print "\n";
$test=		qq{   hello \n\n world   \n};
$expected=	qq{WS|BODYWORD|WS|NL|WS|BODYWORD|WS|NL}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - Whitespace");

# === heading ===
##=== heading ===
##*H3|WS|BODYWORD|WS|H3
print "\n";
$test=		qq{=== heading ===};
$expected=	qq{H3|WS|BODYWORD|WS|H3}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - balanced headings");

# === heading ==\n== heading ===
##=== heading ==\n== heading ===
##*H2|UNKNOWN|WS|BODYWORD|WS|H2|NL|H2|WS|BODYWORD|WS|H2|UNKNOWN
print "\n";
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
print "\n";
$test=		qq{=== heading\n ===};
$expected=	qq{H3|WS|BODYWORD|NL|WS|UNKNOWN}; #rendertext(tokenise($test));
is( rendertokens(tokenise($test)) , $expected, "Tokenising - balanced headings");
# [[DTS
#]]
##[[DTS
##]]
##*ILINK_O|BODYWORD|NL|ILINK_C
say "Using SIMPLEPARSER...\n";
$test=		qq<==hello{{[[dts]]world  {{hello}}}} }}==>;
$expected=	qq{IGNORE|BODYTEXT|IGNORE|BODYTEXT|IGNORE};
is( rendertokens(parse($test)) , $expected, "Tokenising - templates and optimising and simplifying");
print "\n";
is( rendertext(parse($test)) , $test, "Tokenising and rendering fidelity");

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

### TODO more url tests here...

print "\n";
$test=		q{mailto:kevin@example.com [mailto://kevin@example.com] [mailto://kevin@example.com?subject=hello%20world! A great site!]};
$expected=	qq{MAILTO|WS|ELINK_O|MAILTO|ELINK_C|WS|ELINK_O|MAILTO|WS|BODYWORD|WS|BODYWORD|WS|BODYWORD|EXCLAMATION|ELINK_C};
is( rendertokens( tokenise($test)), $expected, "External link and mailto tokeniser");
print "\n";
is( rendertext( tokenise($test)), $test, "External link and mailto tokeniser - rendering fidelity");

#rendertokens( MediaWikiParser::_parsetable_simple ( tokenise($test)));