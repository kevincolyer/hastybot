#!/usr/bin/perl

use 5.10.0;
#use warnings;
use strict;

use utf8;
binmode STDOUT, ":encoding(UTF-8)";
use warnings FATAL => qw(uninitialized);
use Data::Dumper::Simple;

package MediaWikiParser;
 
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 0.99;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw(tokenise parse render);
#our %EXPORT_TAGS = ( DEFAULT => [qw(&tokenise) ] );

our %tokens = (
BODYWORD	=> qr/(\w*)/,
WS		=> qr/(\s*)/,
NEWLINE		=> qr/(\n*)/,
ILINK_O		=> qr/(\[)/,
ILINK_C		=> qr/(\])/,
TEMPL_O		=> qr/(\{\{)/,
TEMPL_C		=> qr/(\}\})/,
ELINK_O		=> qr/(\[\[)/,
ELINK_C		=> qr/(\]\])/,
URL		=> qr/(http)/,  #improve with regex module
HEADING_O	=> qr/^(=*)/,
HEADING_C	=> qr/[\s\b](=*)/,
NOWIKI_O	=> qr/()/i,
NOWIKI_C	=> qr/(<\/\s+nowiki>)/i,
HTML_O		=> qr/(<\w+.*?>)/,
HTML_C		=> qr/(<\/\w*>)/,
HTML_SINGLE	=> qr/(<\/\w*>)/,
#UNKNOWN - does not need a token...
);


sub tokenise {
    my $text = shift;
    my @stack ;
    my @token = [ "NOP", $text];
    push @stack, @token;
    warn Dumper @stack;
    return @stack;
}

sub parse {
    return ;
}

sub render {
    my $text;
    my (@stack) = @_;
    $text = join "|", map {  @{$_}[1]  } @stack;
    return $text;
}
1;