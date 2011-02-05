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

say "You are using version: $MediaWikiParser::VERSION of MediaWikiParser";
 
use Test::More qw( no_plan ); #tests => 3;

$MediaWikiParser::debug=0; # make loud
$MediaWikiParser::timed=1; # make instrumented

my ($test,$expected);

say "\nParsing howtowriteinwiki.dat";
open FILE, "<howtowriteinwiki.dat";
$test = do { local $/; <FILE> };
my @stack = flatten (parse($test)); 
