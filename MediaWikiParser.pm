#!/usr/bin/perl

use 5.10.0;
#use warnings;
use strict;

use utf8;
binmode STDOUT, ":encoding(UTF-8)";
use warnings FATAL => qw(uninitialized);
use Data::Dumper::Simple;
use Regexp::Common qw /URI/;

package MediaWikiParser;
 
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 0.99;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw(tokenise parse rendertext rendertokens);
#our %EXPORT_TAGS = ( DEFAULT => [qw(&tokenise) ] );

sub tokenise {
    my ($text) = @_;
    my @stack ;
    my $nowiki=0;
    my $htmlcom=0;
    my $heading=0;
   # my $URI=qr/$RE{URI}{-keep}/;
    my $tokens = sub {
	TOKEN: { 
	    #return ['URL',         $1]	if $text =~ /\G	$RE{URI}{-keep}	/gcxi;  #improve with regex module
	    return ['NOWIKI_O',    $1] 	if $text =~ /\G	(<nowiki>)	/igcx;
	    return ['NOWIKI_C',    $1] 	if $text =~ /\G	(<\/\s*nowiki>)	/igcx;
	    return ['HTMLCOM_O',   $1] 	if $text =~ /\G	(<!--)		/gcx;
	    return ['HTMLCOM_C',   $1] 	if $text =~ /\G	(-->)		/gcx;

	    return ['MAGICWORD',   $1] 	if $text =~ /\G	(__[A-Z]{1,}__)	/gcx;
	    return ['BODYWORD',    $1] 	if $text =~ /\G (\w+)		/gcx;
	    return ['NL',          $1]	if $text =~ /\G (\n+)		/gcx;
	    return ['WS', 	   $1]	if $text =~ /\G (\s)		/gcx;#seems to gobble newlines
	    return ['BOLD',	   $1]  if $text =~ /\G (''')		/gcx;
	    return ['ITALIC',	   $1]  if $text =~ /\G ('')		/gcx;
	    return ['APOSTROPHY',  $1]  if $text =~ /\G (')^'		/gcx;
	    return ['HEADING_O',   $1] 	if $text =~ /\G ^(=+)		/gcxm; #need m for multiline to enable anchors here...
	    return ['HEADING_C',   $1] 	if $text =~ /\G (=+)		/gcx;

	    #BULLET
	    #NUMBERLIST
	    #DEFINITION
	    #TABLES!!!!

	    return ['ELINK_O',     $1]	if $text =~ /\G (\[)^\[		/gcx;
	    return ['ELINK_C',     $1]	if $text =~ /\G (\])^\[		/gcx;
	    return ['TEMPL_O',     $1] 	if $text =~ /\G	(\{\{)		/gcx;
	    return ['TEMPL_C',     $1] 	if $text =~ /\G	(\}\})		/gcx;
	    return ['ILINK_O',     $1] 	if $text =~ /\G	(\[\[)		/gcx;
	    return ['ILINK_C',     $1] 	if $text =~ /\G	(\]\])		/gcx;
	    return ['HTML_O',      $1] 	if $text =~ /\G	(<\w+.*?>)	/gcx;
	    return ['HTML_C',      $1] 	if $text =~ /\G	(<\/\s*\w*>)	/gcx;
	    return ['HTML_SINGLE', $1]	if $text =~ /\G(<\/+\s*\w*\s*\/+>)/gcx;

	    return ['UNKNOWN',     $1] 	if $text =~ /\G (.)		/gcx;
	    #redo TOKEN if 
	    return undef;
	} ;
    };
    my ($this, $last);
    $last="n/a";
    while (my $tok=$tokens->()) {
	# comments 
	# opening and closing comments
	# $nowiki $htmlcom
	# htmlcomments
	if ($tok->[0] eq 'HTMLCOM_O') {
	    if ($nowiki or $htmlcom) {$tok->[0] = 'IGNORE'}
	    else {$tok->[0] = 'HTMLCOM'; $htmlcom=1}
	};
	if ($tok->[0] eq 'HTMLCOM_C') {
	    if ($nowiki or !$htmlcom) {$tok->[0] = 'UNKNOWN'}
	    else {$tok->[0] = 'HTMLCOM'; $htmlcom=0}
	};
	#nowiki comments
	if ($tok->[0] eq 'NOWIKI_O') {
	    if ($nowiki or $htmlcom) {$tok->[0] = 'IGNORE'}
	    else {$tok->[0] = 'NOWIKI'; $nowiki=1}
	};
	if ($tok->[0] eq 'NOWIKI_C') {
	    if (!$nowiki or $htmlcom) {$tok->[0] = 'UNKNOWN'}
	    else {$tok->[0] = 'NOWIKI'; $nowiki=0}
	};
	#process links here and other nested items
	if ($tok->[0] eq 'NL') {$heading=0;}; #reset heading on newline
	if ($tok->[0] eq 'HEADING_O') {
	    if ($heading) {die ("this can not happen - heading_o is always first!");}
	    $heading = length ($tok->[1]);
	    $tok->[0] = "H$heading";
	};
	if ($tok->[0] eq 'HEADING_C') {
	    if (!$heading) {$tok->[0] = 'UNKNOWN'}
	    else {
		$heading=length($tok->[1]);
		$tok->[0] = "H$heading";
		$heading=0;
	    }
	};#TODO make a == heading = become a h1 and a = heading == h1 also! match and re-write. Perhaps peek?

	#If in a comment - ignore the text
	if ($nowiki+$htmlcom and $tok->[0] ne 'NOWIKI' and $tok->[0] ne 'HTMLCOM') {
	    $tok->[0] = 'IGNORE';
	}
	#now comments are done we can get on with some other things and not worry about comments
	#nowiki comments
	if ($tok->[0] eq 'NOWIKI_O') {
	    if ($nowiki or $htmlcom) {$tok->[0] = 'IGNORE'}
	    else {$tok->[0] = 'NOWIKI'; $nowiki=1}
	};
	if ($tok->[0] eq 'NOWIKI_C') {
	    if (!$nowiki or $htmlcom) {$tok->[0] = 'UNKNOWN'}
	    else {$tok->[0] = 'NOWIKI'; $nowiki=0}
	};


	#
	# some optimisation to reduce tokens
	$this=$tok->[0];
	if ($this eq $last && ($this eq 'UNKNOWN' or $this eq 'IGNORE' or $this eq 'WS')) {
	    $stack[-1]->[1].=$tok->[1];
	    next;
	}
	push @stack, $tok;
	$last=$this;
    }
    #warn Dumper @stack;
    return @stack;
}


sub parse {
    return ;
}

sub rendertext {
   # _render("|",1,@_);
    _render("" ,1,@_);
}

sub rendertokens {
    _render("|",0,@_)
}
sub _render {
    my $text;
    my ($join,$which,@stack) = @_;
    $text = join $join, map {  @{$_}[$which]  } @stack;
    say $text;
    return $text;
}

1;