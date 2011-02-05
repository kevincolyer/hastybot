#!/usr/bin/perl

use 5.10.0;
use strict;
# licence - perl artistic licence...
use utf8;
binmode STDOUT, ":encoding(UTF-8)";
use warnings FATAL => qw(uninitialized);
use Data::Dumper::Simple;

package HastyBotParsers;
use lib "/home/kevin/Dropbox/development/modules";
use MediaWikiParser qw(tokenise parse rendertext rendertokens customparser flatten reduce make_iterator);
#say "You are using version: $MediaWikiParser::VERSION of MediaWikiParser";

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw(parseheadingtext);

our $debug=0;


sub parseheadingtext {
    my ($edit, $unflatten) = @_;
    my %o1 = (
    IGNORE 	=> 'IGNORE', #might always need this? 
    UNKNOWN	=> 'BODYTEXT', #might always need this? 
    BODYWORD 	=> 'BODYTEXT',    
    BAR 	=> 'BODYTEXT',        
    POINT 	=> 'BODYTEXT',       
    COLON 	=> 'BODYTEXT',       
    SEMICOLON 	=> 'BODYTEXT',   
    EXCLAMATION => 'BODYTEXT', 
    NL 		=> 'BODYTEXT',          
    WS 		=> 'BODYTEXT', 	   
    APOSTROPHY 	=> 'BODYTEXT',  
  
    H1		=> 'H1',
    H2		=> 'H2',
    H3		=> 'H3',
    H4		=> 'H4',
    H5		=> 'H5',
    H6		=> 'H6',

    MAGICWORD 	=> 'IGNORE',
    PRE_O 	=> 'IGNORE',      
    PRE_C 	=> 'IGNORE',      
    HTML_O 	=> 'IGNORE',      
    HTML_C 	=> 'IGNORE',  
    HTML_BODY	=> 'IGNORE',
    HTML_SINGLE	=> 'IGNORE', 

    # may not want these but here for now - ignored in pass2
    ELINK_O	=> 'ELINK',     
    ELINK_C 	=> 'ELINK',  
    ELINKMAILTO	=> 'ELINKMAIILTO',
    ELINKCOMMENT=> 'ELINKCOMMENT',  	# for now otherwise ELINK
    ILINK_O 	=> 'ILINK',     
    ILINK_C 	=> 'ILINK',   
    ILINK_PAGE	=> 'ILINK',		# for now
    ILINK_COMMENT=> 'BODYTEXT',		# for now

);
my %o2 = (
    #
    # PASS2...
    IGNORE 	=> 'IGNORE', 		# needed for pass2
    UNKNOWN 	=> 'IGNORE', 

    BODYTEXT	=> 'BODYTEXT', 		# needed for pass 2
    HTML 	=> 'IGNORE',
    TEMPLATE	=> 'IGNORE',
    ILINK 	=> 'IGNORE',
    ELINK 	=> 'IGNORE',
    TABLE 	=> 'IGNORE',

    H1		=> '1',
    H2		=> '2',
    H3		=> '3',
    H4		=> '4',
    H5		=> '5',
    H6		=> '6',
    HTMLCOM 	=> 'IGNORE',
    NOWIKI 	=> 'IGNORE',
    URL 	=> 'IGNORE',
);
    my @parsers = qw(	_parseheading 
			_parsetemplate_simple 
			_parseelink
			_parseilink_simple
			_parsetable_simple	);
    my @stack= customparser($edit, \%o1, \%o2, @parsers);
    
    # run a custom parser on text... output in stack
    # convert nested heading bodytext to headingtext
    # flatten
    # return bit by bit
    for (0..@stack-1) {
# 	say $_;
	my $tok= $stack[$_];
	#say $tok->[0],$tok->[1];
	if ($tok->[0] =~ /\d/) {
	    map {  $_->[0] =~ s/BODYTEXT/HEADINGTEXT/ } @{ $tok->[1] };
	#    $tok->[0] = 'IGNORE';     # don't want heading number anymore 
	}
	$tok->[0] =~ s/BODYTEXT/IGNORE/ ; # no body text either outside of headings
    }
    
     if (!$unflatten) { @stack=flatten(@stack) }
    @stack= reduce( @stack);
#     warn Dumper @stack;
    return @stack;
}




1;