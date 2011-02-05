#!/usr/bin/perl

use 5.10.0;
#use warnings;
use strict;

use utf8;
binmode STDOUT, ":encoding(UTF-8)";
use warnings FATAL => qw(uninitialized);
use Data::Dumper::Simple;
use Tie::File::AsHash;

package Titlecase;
 
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 0.99;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw(titlecase isanacronym ucfirstimproved possibleacronym);
#our %EXPORT_TAGS = ( DEFAULT => [qw(&titlecase &isanacronym &ucfirstimproved &possibleacronym) ] );

#lower cases all and then ignoring starting punctuation, uppercase the first word of the string of which each word has been filtered for words that should not be titlecased and then titlecasesd using ucfirstimproved (which ignores initial punctuation in order to correctly punctuate quoted strings). Removes multiple spaces too for good measure.

#English only!

sub titlecase {
    my ($s) = @_;
    return $s if $s=~ m/.*\[+.*\]+.*/; #if one or more square brackets then give up
    return "" if $s eq ""; # sanity for null strings
    $s =~ s/\s\&(amp;)?\s/ and /g;# get rid of horrid ampersands...
    my $ts = substr($s,-1)eq " " ? " " : ""; # if trailing space then keep it (hack)
    #say "$ts|ping";
    $s = join " ", map { _titlecasemangler($_) } split /\s+/, $s;
    $s = ($s=~ m/^[^a-z]*(\w+)/i && isacronym($1)) ? $s.$ts : ucfirstimproved( $s.$ts ) ;
    # two word alternations
    $s =~ s/(Appendix )([a-z]|[IVXivx]+)/$1.uc($2)/ge; # get Appendix A or I, II, VI etc
    $s =~ s/([IVXivx]+)(\.\s)/uc($1).$2/ge; # get Appendix A or I, II, VI etc
    # corner cases...
    $s =~ s/\. it/. It/g; # for some reason there are sentences in headings... this is a corner case    
    $s =~ s/go manual/GO Manual/ig; # corner case 
    $s =~ s/\&nbsp;/&nbsp;/ig; # corner case     
    return $s;
};
sub _titlecasemangler {
    my ($s) = @_;
    # if a compound word joined with / or - then split mangle on both bits...
    return _titlecasemangler2($s) if $s !~ m/\b[-\/]\b/;
    return join '/', map {_titlecasemangler2($_)} split '/', $s if $s =~ m/\//;
    return join '-', map {_titlecasemangler2($_)} split '-', $s if $s =~ m/-/;
    return $s;
    #$s =~ m/(\w+)([\/-])(.*)/;
    #return _titlecasemangler2($1).$2._titlecasemangler2($3);
}

sub _titlecasemangler2 {
	my ($s) = @_;
	return lc($s) if $s=~ m/^\d+(st|nd|rd|th)[^a-z]*$/i ; # ignore 1st 2nd, 3rd, 4th etc.
	return lc($s) if $s=~ m/^[^a-z]*(a(nd?|s|t|m)*|b(ut|y)|do|en|for|i[fnst]|o[fnr]|t[he|o]*|vs?\.?|via|etc|e\.g)[\,\."':;]*$/i; # return lowercased ignore words  
	# handle acronyms well - via a hash
	my $acro=isacronym($s);
	return $acro if $acro;# if there is an acronym correct and return
	return ucfirstimproved(lc($s)); #so now we title case it!
};

sub isacronym {
    my %acr = (
    http	=> 'http',
    https	=> 'https',
    ftp		=> 'ftp',
    mailto	=> 'mailto',
    html	=> 'HTML',
    rss		=> 'RSS',
    css		=> 'CSS',
    cms		=> 'CMS',
    php		=> 'PHP',
    pr		=> 'PR',
    welc	=> 'WELC',
    welt	=> 'WELT',
    ywam 	=> 'YWAM',
    ywamer 	=> 'YWAMer',
    ywamers	=> 'YWAMers',
    dts		=> 'DTS',
    bls		=> 'BLS',
    soe		=> 'SOE',
    sofm	=> 'SOFM',
    uofn	=> 'UofN',
    ywamkb	=> 'YWAMKB',
    kb		=> 'KB',
    isbn	=> 'ISBN',
    pdf		=> 'PDF',
    pdfs	=> 'PDFs',
    uk		=> 'UK',
    hiv		=> 'HIV',
    aids	=> 'AIDS',
    awol	=> 'AWOL',
    glt		=> 'GLT',
    nlt		=> 'NLT',
    blt		=> 'BLT',
    elf		=> 'ELF',
    xml		=> 'XML',
    crit	=> 'CRIT',
    dna		=> 'DNA',
    agm		=> 'AGM',
    swot	=> 'SWOT',
    faq		=> 'FAQ',
    kbian	=> 'KBian',
    xxx		=> 'XXX',
    xp		=> 'XP',
    diy		=> 'DIY',
    DVD		=> 'DVD',
    knowledgebase => 'KnowledgeBase',
    ywamknowledgebase => 'YWAMKnowledgeBase',
    );
    my ($key) = @_;
    $key=~ m/([^a-z]*)([a-z]*)(.*)/i; #place before, middle and after into search variables
    $key=lc($2);
    if (!defined $acr{$key} && $2 eq uc($key) && length($2)>2 ) {possibleacronym($2)};
    return 0 if !defined $acr{$key}; #if there is no match then return
    return $1.$acr{$key}.lc($3) ;  #send back reassembled acronym
};

{ my %possacro; #declare static
sub possibleacronym {
    
    foreach my $key (@_) {
	$possacro{$key}="seen";
    }
    return  %possacro;
};
};

sub ucfirstimproved {
    my ($s)= @_;
    $s=~ s/([^a-z]*)([a-z])(.*)/$1.uc($2).$3/gei; #(globally match, eval and insensitive search)
    return $s;

};

1;