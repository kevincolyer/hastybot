#!/usr/bin/perl

use warnings;
use strict;
use 5.10.1;
# use Data::Dumper::Simple;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

use lib "/home/kevin/Dropbox/development/modules";

#use Titlecase qw(titlecase isanacronym ucfirstimproved possibleacronym);
use MediaWikiParser qw(tokenise parse rendertext rendertokens customparser flatten mergetokens);
use HastyBotParsers qw(parseheadingtext);

say "You are using version: $MediaWikiParser::VERSION of MediaWikiParser";
 
use Test::More tests => 3;

$MediaWikiParser::debug=0; # make loud
$MediaWikiParser::debugtokens=0; # make defenning!
$MediaWikiParser::timed=0; # make instrumented

my ($test,$expected,$data);

$data="howtowriteinwiki.dat"; # "howtowriteinwiki.dat"
say "\nParsing $data";
open FILE, "<".$data;
$test = do { local $/; <FILE> };

say "tokenising";
ok ( say my @stream = tokenise($test) 					,"tokenising");
ok ( say MediaWikiParser::rendertokensbartext (@stream)			,"tokens and bars");
ok ( say MediaWikiParser::rendertokensbartext (parseheadingtext($test)) ,"tokens bars heading text parser");