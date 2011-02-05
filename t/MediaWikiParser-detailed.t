#!/usr/bin/perl

use warnings;
use strict;
use 5.10.0;
use Data::Dumper::Simple;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

use lib "/home/kevin/Dropbox/development/modules";

#use Titlecase qw(titlecase isanacronym ucfirstimproved possibleacronym);
use MediaWikiParser qw(tokenise parse rendertext rendertokens customparser flatten reduce);
use HastyBotParsers qw(parseheadingtext);

say "You are using version: $MediaWikiParser::VERSION of MediaWikiParser";
 
use Test::More qw( no_plan ); #tests => 3;

$MediaWikiParser::debug=0; # make loud
$MediaWikiParser::debugtokens=0; # make defenning!
$MediaWikiParser::timed=0; # make instrumented

my ($test,$expected,$data);

$data="howtowriteinwiki.dat"; # "howtowriteinwiki.dat"
say "\nParsing $data";
open FILE, "<".$data;
$test = do { local $/; <FILE> };

say "tokenising";
say my @stack = tokenise($test); 
say MediaWikiParser::rendertokensbartext (@stack);
say MediaWikiParser::rendertokensbartext (parseheadingtext($test));