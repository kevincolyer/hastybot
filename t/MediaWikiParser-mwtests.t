#!/usr/bin/perl

use Modern::Perl;
use autodie;
# use Data::Dumper::Simple;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

use lib "/home/kevin/Dropbox/development/modules";

#use Titlecase qw(titlecase isanacronym ucfirstimproved possibleacronym);
use MediaWikiParser qw(tokenise parse rendertext rendertokens renderhtml customparser flatten mergetokens);
use HastyBotParsers qw(parseheadingtext);

say "You are using version: $MediaWikiParser::VERSION of MediaWikiParser";
 
use Test::More qw(no_plan);

$MediaWikiParser::debug=0; # make loud
$MediaWikiParser::debugtokens=0; # make defenning!
$MediaWikiParser::timed=0; # make instrumented

my ($test,$expected,$data);

$data="howtowriteinwiki.dat"; # "howtowriteinwiki.dat"
say "\nParsing $data";
open FILE, "<".$data;
$test = do { local $/; <FILE> };

# say "tokenising";
# ok ( say my @stream = tokenise($test) 					,"tokenising");
# ok ( say MediaWikiParser::rendertokensbartext (@stream)			,"tokens and bars");
# ok ( say MediaWikiParser::rendertokensbartext (parseheadingtext($test)) ,"tokens bars heading text parser");

my $testdata="parserTests.txt"; # MediaWiki parser test file"
say "\nParsing $testdata";
open FILE, "<".$testdata;

#      45 article
#       9 config
#     596 end
#      45 endarticle
#     596 input
#     175 options
#     596 result
#     596 test
#      45 text

# for now skip all !!article -> !!endarticle
my $state="";
my $state2="";
my @tests;
my %testlist;
my $prefix=qr/^!!\s? /x;
while (<FILE>) {
    # say "$.:$_|$state|$state2";
    next if (/^$/ or /^#/) and $state eq "";
    if ($state eq "article") {
	$state="" if /$prefix endarticle/ox;
	next; # ignore
    }
    if ($state eq "") {
	do {$state2="test" ; $state="intest"} if /$prefix test/ox;
	next;
    }
    if ($state eq "intest") {
	do{$state2="ignore" ; next} if /$prefix options/ox;
	do{$state2="ignore" ; next} if /$prefix article/ox;
	do{$state2="ignore" ; next} if /$prefix config/ox;
	do{$state2="ignore" ; next} if /$prefix text/ox;

	do{$state2="input"  ; next} if /$prefix input/ox;
	do{$state2="result" ; next} if /$prefix result/ox;
			    next if $state2 eq "ignore";
	if (/$prefix end/ox) {
	    $state2 =  $state = "" ;
	    chomp $testlist{test};
	    push @tests, { %testlist } ;
	    # say for keys %testlist;
	    $testlist{$_}="" for keys %testlist; # empty hash for next time
	    next;
	}
	$testlist{$state2}.=$_ ;
	next;
    }
    die "Unexpected input:$_";
}

# now to run the tests...
my ($i, @ii, $e, $num);
for my $t  (@tests) {
    $num++;
#     say "$num: ".$t->{test};
#     say $t->{input};
    exit if $num>10; # go step by step
    @ii=tokenise( $t->{input} );
    $i=renderhtml( @ii );
    $e=$t->{result} ||= ""; # to remove undefs...
    is( $i , $e , $t->{test} );
    };