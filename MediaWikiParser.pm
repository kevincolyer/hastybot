#!/usr/bin/perl

use 5.10.0;
#use warnings;
use strict;

use utf8;
binmode STDOUT, ":encoding(UTF-8)";
use warnings FATAL => qw(uninitialized);
use Data::Dumper::Simple;
#use Regexp::Common qw /URI/;

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
	    #	    'URL'
	    return ['MAILTO',      $1] 	if $text =~ /\G (mailto:)	/gcxi;
	    return ['HTTP',        $1] 	if $text =~ /\G (http:\/\/|https:\/\/)	/gcxi;
	    return ['FTP',         $1] 	if $text =~ /\G (ftp:\/\/|ftps:\/\/)	/gcxi;
	    #	    'NOWIKI'
	    return ['NOWIKI_O',    $1] 	if $text =~ /\G	(<nowiki>)	/igcx;
	    return ['NOWIKI_C',    $1] 	if $text =~ /\G	(<\/\s*nowiki>)	/igcx;
	    #       'HTMLCOM'
	    return ['HTMLCOM_O',   $1] 	if $text =~ /\G	(<!--)		/gcx;
	    return ['HTMLCOM_C',   $1] 	if $text =~ /\G	(-->)		/gcx;

	    #	    'IGNORE' (AND UNKNOWN)
	    return ['MAGICWORD',   $1] 	if $text =~ /\G	(__[A-Z]{1,}__)	/gcx;
	    #	    'BODYTEXT'
	    return ['BODYWORD',    $1] 	if $text =~ /\G (\w+)		/gcx;
	    return ['BAR',         $1] 	if $text =~ /\G (\|)		/gcx;
	    return ['POINT',       $1] 	if $text =~ /\G (\.)		/gcx;
	    return ['COLON',       $1] 	if $text =~ /\G (:)		/gcx;
	    return ['SEMICOLON',   $1] 	if $text =~ /\G (;)		/gcx;
	    return ['EXCLAMATION', $1] 	if $text =~ /\G (!)		/gcx;
	    return ['NL',          $1]	if $text =~ /\G (\n+)		/gcx;
	    return ['WS', 	   $1]	if $text =~ /\G (\s)		/gcx;#seems to gobble newlines
	    return ['BOLD',	   $1]  if $text =~ /\G (''')		/gcx;
	    return ['ITALIC',	   $1]  if $text =~ /\G ('')		/gcx;
	    return ['APOSTROPHY',  $1]  if $text =~ /\G (')^'		/gcx;
	    # 	    'HEADING'
	    return ['HEADING_O',   $1] 	if $text =~ /\G ^(=+)		/gcxm; #need m for multiline to enable anchors here...
	    return ['HEADING_C',   $1] 	if $text =~ /\G (=+)		/gcx;
	    #BULLET
	    #NUMBERLIST
	    #DEFINITION
	    #	    'TABLE'
	    return ['TABLE_O',     $1]	if $text =~ /\G (\{\|)		/gcx;
	    return ['TABLE_C', 	   $1]	if $text =~ /\G (\|\})		/gcx;
	    #	    'ELINK'
	    return ['ELINK_O',     $1]	if $text =~ /\G (\[)^\[		/gcx;
	    return ['ELINK_C',     $1]	if $text =~ /\G (\])^\[		/gcx;
	    #	    'TEMPLATE'
	    return ['TEMPL_O',     $1] 	if $text =~ /\G	(\{\{)		/gcx;
	    return ['TEMPL_C',     $1] 	if $text =~ /\G	(\}\})		/gcx;
	    #	    'ILINK'
	    return ['ILINK_O',     $1] 	if $text =~ /\G	(\[\[)		/gcx;
	    return ['ILINK_C',     $1] 	if $text =~ /\G	(\]\])		/gcx;
	    #	    'HTML'
	    return ['HTML_O',      $1] 	if $text =~ /\G	(<\w+.*?>)	/gcx;
	    return ['HTML_C',      $1] 	if $text =~ /\G	(<\/\s*\w*>)	/gcx;
	    return ['HTML_SINGLE', $1]	if $text =~ /\G(<\/+\s*\w*\s*\/+>)/gcx;

	    return ['UNKNOWN',     $1] 	if $text =~ /\G (.)		/gcx;
	    #groups
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
	    else {$htmlcom=1} #$tok->[0] = 'HTMLCOM'
	};
	if ($tok->[0] eq 'HTMLCOM_C') {
	    if ($nowiki or !$htmlcom) {$tok->[0] = 'UNKNOWN'}
	    else {$htmlcom=0} #$tok->[0] = 'HTMLCOM'; 
	};
	#nowiki comments
	if ($tok->[0] eq 'NOWIKI_O') {
	    if ($nowiki or $htmlcom) {$tok->[0] = 'IGNORE'}
	    else {$nowiki=1} #$tok->[0] = 'NOWIKI';
	};
	if ($tok->[0] eq 'NOWIKI_C') {
	    if (!$nowiki or $htmlcom) {$tok->[0] = 'UNKNOWN'}
	    else {$nowiki=0} #$tok->[0] = 'NOWIKI';
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
	if ($nowiki+$htmlcom and $tok->[0] !~ /NOWIKI.*/ and $tok->[0] !~ /HTMLCOM.*/) {
	    $tok->[0] = 'IGNORE';
	}
	#now comments are done we can get on with some other things and not worry about comments
	#nowiki comments
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
    #simple parser
    return _searchtextparser(tokenise(@_));
}

sub rendertext {
    _render("|",1,@_);
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

sub _searchtextparser {
    my (@stack) =@_;
    my @returnstack;
    my %groups = (
	MAILTO 		=> 'URL',      
	HTTP 		=> 'URL',        
	FTP 		=> 'URL',         
	NOWIKI_O 	=> 'NOWIKI',    
	NOWIKI_C 	=> 'NOWIKI',    
	HTMLCOM_O 	=> 'HTMLCOM',   
	HTMLCOM_C 	=> 'HTMLCOM',   

	MAGICWORD 	=> 'IGNORE',  	 #in this case

	BODYWORD 	=> 'BODYTEXT',    
	BAR 		=> 'BODYTEXT',        
	POINT 		=> 'BODYTEXT',       
	COLON 		=> 'BODYTEXT',       
	SEMICOLON 	=> 'BODYTEXT',   
	EXCLAMATION 	=> 'BODYTEXT', 
	NL 		=> 'BODYTEXT',          
	WS 		=> 'BODYTEXT', 	   
	BOLD 		=> 'IGNORE', 		  #in this case   
	ITALIC 		=> 'IGNORE', 		  #in this case	   
	APOSTROPHY 	=> 'BODYTEXT',  
	HEADING_O 	=> 'HEADING', 
	HEADING_C 	=> 'HEADING',  
	TABLE_O 	=> 'TABLE',     
	TABLE_C		=> 'TABLE', 	   
	
	ELINK_O		=> 'ELINK',     
	ELINK_C 	=> 'ELINK',     
	
	TEMPL_O 	=> 'TEMPLATE',     
	TEMPL_C 	=> 'TEMPLATE',     
	
	ILINK_O 	=> 'ILINK',     
	ILINK_C 	=> 'ILINK',   
	
	HTML_O 		=> 'HTML',      
	HTML_C 		=> 'HTML',      
	HTML_SINGLE	=> 'HTML', 

	UNKNOWN 	=> 'IGNORE',  
	#
	#used in pass 2
	BODYTEXT	=> 'BODYTEXT', 		# needed for pass 2
	IGNORE 		=> 'IGNORE', 		# needed for pass2
	HTML 		=> 'IGNORE',
	TEMPLATE	=> 'IGNORE',
	ILINK 		=> 'IGNORE',
	ELINK 		=> 'IGNORE',
	TABLE 		=> 'IGNORE',
	HEADING 	=> 'IGNORE',
	HTMLCOM 	=> 'IGNORE',
	NOWIKI 		=> 'IGNORE',
	URL 		=> 'IGNORE',
    );
    #templates => ignore
    my $templatedepth=0;
    while (@stack) {
	my $tok = shift @stack;
	my $this=$tok->[0];
	if ($this eq 'TEMPL_O') {
	    $templatedepth++;
	    #$tok->[0]='TEMPLATE';
	    push @returnstack, $tok;# mark as template
# 	    my $template=_simpletextparser(@stack);#call self with remains of token stream
# 	    push @returnstack, $template;#put token stream back in stack
	    next};
	if ($this eq 'TEMPL_C') {
	    if ($templatedepth==0) {#ignore close template if no prev. matching
		$tok->[0]='IGNORE'}
	    else {$templatedepth!=0;#cloase if open
		#$tok->[0]='TEMPLATE';
		$templatedepth--;#ascend a level
# 		push @returnstack,$tok;
# 		return @returnstack;#return as we recusively call self to process templates
	    }
	} elsif ($templatedepth!=0) {$tok->[0]='IGNORE';};
	push @returnstack, $tok;
    };
    @stack=@returnstack;
    #warn Dumper @stack;
    #elink => ignore
    #ilink => ignore
    #tables => ignore
    #
    #optimise - simplify to bodytext or ignore
    @stack=_simplify(%groups¸@returnstack);
    #optimise - combine adjacant identical tokens
    @stack=_optimise(@stack);
    return @stack;
}

sub _optimise {
    my (@stack)=@_;
    my @returnstack;
    if (length @stack >1) {
	my $tok= shift @stack;
	my $last=$tok->[0];
	my $this;
	push @returnstack, $tok;
	while ($tok=shift @stack) {
	    $this=$tok->[0];
	    if ($this eq $last) {
		  $returnstack[-1]->[1].=$tok->[1];  
		  next;
	    }
	push @returnstack, $tok;
	$last=$this;
	};
    return @returnstack;
    }
    return @stack;
}

sub _simplify {
	my %groups=shift;
	my @returnstack;
	while (my $tok=shift @_) {
	    if (!exists $groups{$tok->[0]}) {warn $tok->[0]." token was not found in simplify hash... Changed to UNKNOWN"; $tok->[0]='UNKNOWN';}; 
	    $tok->[0]=$groups{$tok->[0]}; # pass 1 groups tokens
	    $tok->[0]=$groups{$tok->[0]}; # pass 2 choose which to ignore and which to keep
	    push @returnstack, $tok; #and return the renamed token
	}
	return @returnstack;
    };
1;