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
 
use Test::More qw( no_plan ); #tests => 3;

$MediaWikiParser::debug=0; # make loud
$MediaWikiParser::timed=1; # make instrumented

my ($test,$expected);

say "\nParsing howtowriteinwiki.dat";
open FILE, "<howtowriteinwiki.dat";
$test = do { local $/; <FILE> };
ok (flatten (parse($test)),"parsing file - timed - 456K to beat 23/5/2011"); 

# notes - NEXTVAL is slow compared to ->
# generally closure iterators are slow compared to recursion?
