#!/usr/bin/perl

use warnings;
use strict;
use 5.10.0;
use Data::Dumper::Simple;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

#use Titlecase qw(titlecase isanacronym ucfirstimproved possibleacronym);
use MediaWikiParser qw(tokenise parse render);

say "You are using version: $MediaWikiParser::VERSION of MediaWikiParser";
 
my $test=	qq<==DTS==\nDTS is very cool. I like it. {{RatingBar}}>;
my $expected=	$test;

use Test::More qw( no_plan ); #tests => 3;

is( render( tokenise($test) ) , $expected, "Parsing and re-rendering Integrity Test");

