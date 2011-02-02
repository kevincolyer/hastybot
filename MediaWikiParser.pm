#!/usr/bin/perl

use 5.10.0;
use strict;
# licence - perl artistic licence...
use utf8;
binmode STDOUT, ":encoding(UTF-8)";
use warnings FATAL => qw(uninitialized);
use Data::Dumper::Simple;

use lib "/home/kevin/Dropbox/development/modules";

package MediaWikiParser;
 
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw(tokenise parse rendertext rendertokens debug customparser flatten reduce make_iterator);


our $debug=0;

sub tokenise {
    my ($text) = @_;
    my @stack ;
    my $state_nowiki=0;
    my $state_htmlcom=0;
    my @state_html; # state variable is a stack... perhaps we need a stack here too?


    my $tokens = sub {
	TOKEN: { 
	    #	    'URL'
	    # http regexp inspiration from http://www.wellho.net/resources/ex.php4?item=p212/regextra
	    # tokenise some code and inspiration from MJD's Higher Order Perl...
	    return ['MAILTO',      $1] 	if $text =~ /\G (
							(?:mailto\:)
							(?:\/\/)?		# optional
							(?:[^\s]+)		# before @
							(?:\@)			# must have an @
							(?:(?:[^\s\]\.])+)	# atleast one word
							(?:\.(?:[^\s\]])+)?	# optional . and word
							)		/gcxi;
	    return ['URL',         $1] 	if $text =~ /\G (
							(?:http|https|ftp)
							(?:\:\/\/)  
							(?:[^\:\/\s\]]+)        # server
							(?:\:\d+)?              # port - optional
							(?:\/[^\#\s]+)?         # page - optional
							(?:\#(?:\S*))?          # place - optional
								)	/gcxi;
	    
	    return ['MAGICWORD',   $1] 	if $text =~ /\G	(__[A-Z]{1,}__)	/gcx;
	    return ['BODYWORD',    $1] 	if $text =~ /\G (\w+)		/gcx;
	    return ['NL',          $1]	if $text =~ /\G (\n+)		/gcx; # put above whites space
	    return ['WS', 	   $1]	if $text =~ /\G (\s)		/gcx; # seems to gobble newlines
	    return ['POINT',       $1] 	if $text =~ /\G (\.)		/gcx;
	    return ['NBSP',	   $1] 	if $text =~ /\G	(\&nbsp;)	/gcx;
	    return ['NOWIKI_O',    $1] 	if $text =~ /\G	(<nowiki>)	/igcx;
	    return ['NOWIKI_C',    $1] 	if $text =~ /\G	(<\/nowiki>)	/igcx;
	    #       'HTMLCOM'
	    return ['HTMLCOM_O',   $1] 	if $text =~ /\G	(<!--)		/gcx;
	    return ['HTMLCOM_C',   $1] 	if $text =~ /\G	(-->)		/gcx;
	    #	    'TABLE'
	    return ['TABLE_O',     $1]	if $text =~ /\G (\{\|)		/gcx;
	    return ['TABLE_C', 	   $1]	if $text =~ /\G ^(\|\})	/gcxm; # because |}} bar/templ_e is confused with table_c|ignore...
	    #	    'BODYTEXT'
	    return ['BAR',         $1] 	if $text =~ /\G (\|)	/gcx; # because |}} bar/templ_e is confused
	    return ['COLON',       $1] 	if $text =~ /\G (:)		/gcx;
	    return ['SEMICOLON',   $1] 	if $text =~ /\G (;)		/gcx;
	    return ['EXCLAMATION', $1] 	if $text =~ /\G (!)		/gcx;
	    return ['BOLD',	   $1]  if $text =~ /\G (''')		/gcx;
	    return ['ITALIC',	   $1]  if $text =~ /\G ('')		/gcx;
	    return ['APOSTROPHY',  $1]  if $text =~ /\G (')		/gcx;
	    # 	    'HEADING'
	    return ['HEADING_O',   $1] 	if $text =~ /\G ^(={1,6})	/gcxm; #need m for multiline to enable anchors here...
	    return ['HEADING_C',   $1] 	if $text =~ /\G (={1,6})	/gcx;
	    #BULLET
	    #NUMBERLIST
	    #DEFINITION
	    #	    'ILINK'
	    return ['ILINK_O',     $1] 	if $text =~ /\G	(\[\[)		/gcx;
	    return ['ILINK_C',     $1] 	if $text =~ /\G	(\]\])		/gcx;
	    #	    'ELINK'
	    return ['ELINK_O',     $1]	if $text =~ /\G (\[)		/gcx;
	    return ['ELINK_C',     $1]	if $text =~ /\G (\])		/gcx;
	    #	    'TEMPLATE'
	    return ['TEMPL_O',     $1] 	if $text =~ /\G	(\{\{)		/gcx;
	    return ['TEMPL_C',     $1] 	if $text =~ /\G	(\}\})		/gcx;

	    return ['PRE_O',       $1] 	if $text =~ /\G	(<pre>)		/igcx;
	    return ['PRE_C',       $1] 	if $text =~ /\G	(<\/pre>)	/igcx;  
	    #	    'HTML'
	    return ['HTML_O',      $1] 	if $text =~ /\G	(<\w+.*?>)	/gcx;
	    return ['HTML_C',      $1] 	if $text =~ /\G	(<\/\s*\w*>)	/gcx;
	    return ['HTML_SINGLE', $1]	if $text =~ /\G(<\/+\s*\w*\s*\/+>)/gcx;

	    return ['UNKNOWN',     $1] 	if $text =~ /\G (.)		/gcx;
	    #groups
	    #redo TOKEN if 
	    #only if at then end... drop through... warn "Unmatched token! Something is wrong! at ",pos($text);
	    return undef;
	}
    };

    my ($this, $last);
    $last="n/a";
    while (my $tok=$tokens->() ) {
	# comments 
	# opening and closing comments
	# $state_nowiki $state_htmlcom
	# htmlcomments
	if ($tok->[0] eq 'HTMLCOM_O') {
	    if ($state_nowiki or $state_htmlcom) {$tok->[0] = 'IGNORE'}
	    else {$state_htmlcom= 1; $tok->[0] = 'IGNORE';} 
	};
	if ($tok->[0] eq 'HTMLCOM_C') {
	    if ($state_nowiki or !$state_htmlcom) {$tok->[0] = 'IGNORE'}
	    else {$state_htmlcom=0; $tok->[0] = 'IGNORE';}  
	};
	#nowiki comments
	if ($tok->[0] eq 'NOWIKI_O') {
	    if ($state_nowiki or $state_htmlcom) {$tok->[0] = 'IGNORE'}
	    else {$state_nowiki=1; $tok->[0] = 'IGNORE';} 
	};
	if ($tok->[0] eq 'NOWIKI_C') {
	    if (!$state_nowiki or $state_htmlcom) {$tok->[0] = 'IGNORE'}
	    else {$state_nowiki=0; $tok->[0] = 'IGNORE';}
	};

	# if in a comment - mark text as ignored... 
	if ( $state_nowiki+$state_htmlcom ) { #removed below as redundent - unless I want the tags - prob not...
	    $tok->[0] = 'IGNORE'; #and $tok->[0] !~ /NOWIKI.*/ and $tok->[0] !~ /HTMLCOM.*/
	}

	# now comments are done we can get on with some other things and not worry about comments

	# TODO - inside html....
	# HTML_BODY	=> 'IGNORE',

	# process HEADINGS - moved to _parseheading


	# 
	# some optimisation to reduce tokens
	$this=$tok->[0];
	warn "UNKOWN token encountered |".$tok->[1]."|" if ($this eq 'UNKNOWN' and $debug);
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

###############################################################
sub rendertext {
    $_= _render("" ,1,@_);
    say if $debug;
    return $_;
}

sub rendertextbar {
    $_=_render("|",1,@_);
    say if $debug;
    return $_;
}

sub rendertokens {
    $_=_render("|",0,@_);
    say if $debug;
    return $_;
}

sub rendertokensbartext {
    use Kpctools q<snippet>;
    my (@stack, $text, $first, $len);
    @stack=@_;
    $text="";
    while (my $tok = shift @stack) {
	$text.="\n" if $first++;
	if (ref( $tok->[1] ) eq 'ARRAY') {
	    $text.="\n".$tok->[0].":\n"; #because we want to see the token
	    $text.=rendertokensbartext( @{ $tok->[1] } ); # recurse on dereferenced array
	    $text.="\n"; # show the tokens are a group.
	} else {
	    $len= " " x ( 20-length( $tok->[0] ) );
	    $text.=$tok->[0].$len.$tok->[1];#.snippet( $tok->[1] , 60);
	}
    }
    return $text;
}

sub _render {
    my ($text, $first);
    my ($join,$which,@stack) = @_;
    $text="";
#     warn Dumper @stack;
    while (my $tok = shift @stack) {
	$text.=$join if $first++;
# 	warn Dumper $tok;
	if (ref( $tok->[1] ) eq 'ARRAY') {
	    $text.=$tok->[0].$join if $which==0; # if rendering tokens then we want to see the token of array ref
	    $text.=_render( $join, $which, @{ $tok->[1] } ); # recurse using a dereferenced stack 
	} else {
	    $text.= $tok->[$which];
	}
    }
    return $text;
}

###############################################################
sub parse {
    #simple parser
    #return _testparser(tokenise(@_));
    return _testparser(@_);
}
    
sub make_iterator {
    my (@stack) = @_  ; # process and flatten stack
    return sub {
	return undef if !@stack; # if nothing more return undef
	return shift @stack ; # otherwise return a token and reduce stack
	}
}

sub customparser {
    my ($wikitext,$o1,$o2, @parsers)=@_;
    my @stack=	tokenise($wikitext);
 
    if (!@parsers) { @parsers = qw(_parseheading _parsetemplate_simple _parseelink _parseilink_simple _parsetable_simple) };
    # parse using a chain of sub parsers...
    no strict; # needed for below
    map { @stack =  &$_(@stack) } @parsers; # &$_() creates a sub from the string value in $_
    strict;
#warn Dumper @stack;
    # optimise 	#1 - group tokens, two passes
    @stack=     _simplify($o1, @stack);
    @stack=     _simplify($o2, @stack);
#warn Dumper @stack;
    # optimise 	#2 - combine adjacant identical tokens
    @stack=	reduce(@stack);

    # sanity check
#     if (rendertext(@stack) ne $wikitext) {warn Dumper @stack}; 
    die "Rendering comparison of parsed wikitext failed - critical error. Stopping." if rendertext(@stack) ne $wikitext;
    return @stack;
}

sub _testparser {
    # groups for simplification... 
    my %o1 = (
	MAILTO 		=> 'MAILTO',      
	HTTP 		=> 'URL',        
	FTP 		=> 'URL', 
	URL 		=> 'URL', 
	BAREURL		=> 'BAREURL', 		#for now otherwise url?
	BAREMAILTO	=> 'BAREMAILTO',

	NOWIKI_O 	=> 'NOWIKI',    
	NOWIKI_C 	=> 'NOWIKI',    
	HTMLCOM_O 	=> 'HTMLCOM',   
	HTMLCOM_C 	=> 'HTMLCOM',   

	MAGICWORD 	=> 'IGNORE',  	 	#in this case

	BODYWORD 	=> 'BODYTEXT',    
	BAR 		=> 'BODYTEXT',        
	POINT 		=> 'BODYTEXT',       
	COLON 		=> 'BODYTEXT',       
	SEMICOLON 	=> 'BODYTEXT',   
	EXCLAMATION 	=> 'BODYTEXT', 
	NL 		=> 'BODYTEXT',          
	WS 		=> 'BODYTEXT', 	   
	APOSTROPHY 	=> 'BODYTEXT',  

	BOLD 		=> 'IGNORE', 		#in this case   
	ITALIC 		=> 'IGNORE', 		#in this case	   
	HEADING_O 	=> 'HEADING', 
	HEADING_C 	=> 'HEADING',  
	H1		=> 'H1',
	H2		=> 'H2',
	H3		=> 'H3',
	H4		=> 'H4',
	H5		=> 'H5',
	H6		=> 'H6',
	TABLE_O 	=> 'TABLE',     
	TABLE_C		=> 'TABLE', 	   
	
	ELINK_O		=> 'ELINK',     
	ELINK_C 	=> 'ELINK',  
	ELINKMAILTO	=> 'ELINKMAIILTO',
	ELINKCOMMENT	=> 'ELINKCOMMENT',  	# for now otherwise ELINK
	
	TEMPL_O 	=> 'TEMPLATE',     
	TEMPL_C 	=> 'TEMPLATE',     
	
	ILINK_O 	=> 'ILINK',     
	ILINK_C 	=> 'ILINK',   
	ILINK_PAGE	=> 'ILINK',		# for now
	ILINK_COMMENT	=> 'ILINK',		# for now
	
	
	PRE_O 		=> 'IGNORE',      
	PRE_C 		=> 'IGNORE',      
	HTML_O 		=> 'HTML',      
	HTML_C 		=> 'HTML',      
	HTML_SINGLE	=> 'HTML', 

	UNKNOWN 	=> 'IGNORE',  
	IGNORE 		=> 'IGNORE',
    );
    my %o2 = (
	#
	# PASS2...
	BODYTEXT	=> 'BODYTEXT', 		# needed for pass 2
	IGNORE 		=> 'IGNORE', 		# needed for pass2
	HTML 		=> 'IGNORE',
	TEMPLATE	=> 'IGNORE',
	ILINK 		=> 'IGNORE',
	ELINK 		=> 'IGNORE',
	TABLE 		=> 'IGNORE',
	HEADING 	=> 'IGNORE',
	H1		=> 'H1',
	H2		=> 'H2',
	H3		=> 'H3',
	H4		=> 'H4',
	H5		=> 'H5',
	H6		=> 'H6',
	HTMLCOM 	=> 'IGNORE',
	NOWIKI 		=> 'IGNORE',
	URL 		=> 'IGNORE',
	UNKNOWN 	=> 'IGNORE', 
    );
    my @parsers = qw(	_parseheading 
			_parsetemplate_simple 
			_parseelink
			_parseilink_simple
			_parsetable_simple	);
    return customparser(@_, \%o1, \%o2, @parsers);
}

sub _parseheading { 
    my @returnstack;
    my $state_heading=0;
    my $headinglevel=0;
    my $last ='n/a';
# warn Dumper @_;
    while (my $tok=shift @_) {
# 	warn Dumper $tok;
	if ( ref( $tok->[1] ) eq 'ARRAY')  {
		@{ $tok->[1] } = _parseheading( @{ $tok->[1] } ) ; # dereference and recurse
	}

	if ($tok->[0] eq 'NL') {$headinglevel=0; $state_heading=0}; # reset heading on newline

	if ($tok->[0] eq 'HEADING_O') { # heading OPEN
	    if ($headinglevel) {die ("this can not happen - heading_o is always first!");}
	    $headinglevel = length ($tok->[1]);
	    $state_heading 	  = @returnstack; # stack size +1 will be the index of this item as not inserted into stack yet!
	    $tok->[0]     = "H$headinglevel";
	};

	if ($tok->[0] eq 'HEADING_C') { # heading CLOSE
	    if (!$headinglevel) {$tok->[0] = 'IGNORE'} # ignore close before open
	    else {
		my $closeheading=length($tok->[1]); 
		if ($headinglevel>$closeheading) { # closeheading wins - add an ignore with = x diff after openheading
		    my $tok2 = ['IGNORE','=' x ($headinglevel-$closeheading)];
		    splice(@returnstack,$state_heading+1,0,$tok2); #hopefully add tok2 to just after the first heading
		    $returnstack[$state_heading]->[0]= "H$closeheading";
		    $returnstack[$state_heading]->[1]= "=" x $closeheading;
		    $tok->[0]="H$closeheading";
		}; 
		if ($headinglevel<$closeheading) { # heading wins - add and ignore with = x diff after close heading - reset closeheading
		    $last='IGNORE'; # we move ahead a token so trick optimiser...
		    my $tok2 = [$last,'=' x ($closeheading-$headinglevel)];
		    push @returnstack,$tok2; # push my difference token into stack before current token 
		    $tok->[0]= "H$headinglevel";
		    $tok->[1]= "=" x $headinglevel;
		    $closeheading=$headinglevel;
		    
		}; 
		if ($closeheading==$headinglevel) { # the only other option...
		    $tok->[0] = "H$closeheading";
		};
		# cut out the heading, replace with arrayref and tok h3 etc.
		my @snip= splice (@returnstack, $state_heading);
		#warn Dumper @snip;
		# ignore opening tag and closing semantic meaning no longer neaded
		$snip[0]->[0] = 'IGNORE';
		$tok->[0] = 'IGNORE';
		push @snip, $tok; # put closing tag on too i.e. currently processing one
		#warn Dumper @snip;
		$returnstack[$state_heading]->[1]= \@snip;			# add array ref to stack
		$returnstack[$state_heading]->[0] = "H$closeheading";	# give it a meaningful name
		#warn Dumper @stack;
		# done
		$headinglevel=0;
		$last='IGNORE';
		$state_heading=0;
		
		next; # we've added to stack so now restart the loop.
	    }
	}
	push @returnstack, $tok;
    }
    #warn Dumper @returnstack;
    return @returnstack;
}



sub _parseelink { 
    my @returnstack;
    my $inelink=0;
    my $elinkstart=0;
    my $elinkurl = '';
    my $elinkws=0;
    while (my $tok=shift @_) {
	if ( ref( $tok->[1] ) eq 'ARRAY')  {
		@{ $tok->[1] } = _parseelink( @{ $tok->[1] } ) ; # dereference and recurse
	}

	#if url not in elink then mark as bareurl or baremailto
	#if in an elink then elink-url seek comment, seek white space... mark as elink-comment
	if (!$inelink) { # NOT In an ELINK
	    $tok->[0] = 'BARE'.$tok->[0] if ($tok->[0] eq 'URL' or $tok->[0] eq 'MAILTO'); 
	    $tok->[0] = 'IGNORE' 	 if  $tok->[0] eq 'ELINK_C';  # mistake - not in link and so ignore tag
	    if ($tok->[0] eq 'ELINK_O') {
		$elinkstart=@returnstack;
		$inelink=1;
	    }
	    #say "not in elink: ",$tok->[0],$tok->[1];
	    push @returnstack, $tok; # nothing to see move along please!
	    next;
	}

	if ($inelink) {
	    die "in an elink and found another elink open tag - don;t know what to do. :-(" if $tok->[0] eq 'ELINK_O';
	    
	    if ($tok->[0] eq 'URL' or $tok->[0] eq 'MAILTO') {
		$tok->[0] = 'ELINKCOMMENT' 	if $elinkurl ne '';# multiple url's are comments...'
		$elinkurl = $tok->[0] 		if $elinkurl eq '';
	    }

	    if ($tok->[0] eq 'WS') {
		if ($elinkws==0) {
		    $elinkws=@returnstack; 	# only record first ws seen...
		}			 	# mark WS as IGNORE later
	    }

	    if ($tok->[0] eq 'NL') {
		#reset
# 		for ($elinkstart..@returnstack) {
# 		    $returnstack[$_]->[0]='IGNORE';
# 		}
		$elinkstart=0;
		$inelink=0;
		$elinkws=0;
		$elinkurl='';
	    }
	    
	    if ($tok->[0] eq 'ELINK_C') {
		if ($elinkws) {
		    for ($elinkws+1..@returnstack-1) {
			$returnstack[$_]->[0] = 'ELINKCOMMENT';
		    }
		}
		$returnstack[$elinkstart]->[0] = 'IGNORE';
		$returnstack[$elinkws]->[0] = 'IGNORE';
		$returnstack[$elinkstart+1]->[0] = 'ELINK'.$returnstack[$elinkstart+1]->[0];
		$elinkstart=0;
		$elinkws=0;
		$elinkurl='';
		$inelink=0;
		$tok->[0]='IGNORE';
	    }
	}
	#say " in elink: ",$tok->[0],$tok->[1];
	push @returnstack, $tok;
    }
    if ($inelink) {
	for ($elinkstart..@returnstack) {
	    $returnstack[$_]->[0]='IGNORE';
	}
    }
    #rendertokens(@returnstack);
    #warn Dumper @returnstack;
    return @returnstack;
}
 
sub _parseilink_simple {
    my $open=0;
    my $inilink=0;
    my $firstbar=0;
    my $lastbar=0;
    my @returnstack;
    while (my $tok=shift @_) {
	if ( ref( $tok->[1] ) eq 'ARRAY')  {
		@{ $tok->[1] } = _parseilink_simple( @{ $tok->[1] } ) ; # dereference and recurse
	}

	if ($inilink==0) { 					# if we are not in a link...
	    if ($tok->[0] eq 'ILINK_C') {$tok->[0]='IGNORE'};   # if close before open ignore
	    if ($tok->[0] eq 'ILINK_O') {			# mark opening of elink
		$open=@returnstack;
		#say "open @ $open";
		$inilink=1;
		$firstbar=0;
	        $lastbar=0;
	    }; # ILINK_O ================= END
	    push @returnstack, $tok; 				# anything else drops through...
	    next;
	} 

	# we are in a link...
	if ($tok->[0] eq 'NL') { # NL ==== END			# if eol then Ilink should be ignored... 
	    $returnstack[$open]->[0]='IGNORE'; 
	    $inilink=0;						# mark as not in link
	    push @returnstack, $tok;
	    next;
	    # NL ========================= END
	};
	# ILINK_C =============
	if ($tok->[0] eq 'ILINK_C') {				#finished link success - now re-write and reset vars.
	    if ($firstbar) {
		# >$depth to <$firstbar = ILINK_PAGE
		# >$lastbar to end array = ILINK_COMMENT
		#say "starting rewitre of ilink_page";
		for ($open+1 .. $firstbar-1) {
		    #say $_;
		    $returnstack[$_]->[0]='ILINK_PAGE';
		}
		if ($lastbar) {
		    #say "starting rewitre of ilink_comment";
		    for ($lastbar+1..@returnstack-1) {
			#say $_;
			$returnstack[$_]->[0]='ILINK_COMMENT';
		    }
		}
	    } else { 
		#say "no bars encountered...";
		for ($open+1..@returnstack-1) {
		    #say $_;
		    $returnstack[$_]->[0]='ILINK_PAGE';
		    }
	    };
	    #say "ending rewrite and closing the ilink";
	    $open=0; 
	    $inilink=0;
	    push @returnstack, $tok;
	    next;
	} ; # ILINK_C =====END		
	    # BAR ============
	if ($tok->[0] eq 'BAR') {
	    $firstbar=@returnstack if !$firstbar;	# before is ILINK_PAGE # TODO is this assumption true?
	    $lastbar =@returnstack if  $firstbar;	# last is ILINK_COMMENT
	    $tok->[0]='IGNORE';				# ignore BAR now please
	    #say "first bar $firstbar, last bar $lastbar";
	    push @returnstack, $tok;
	    next;
	}; # BAR ==========END
	$tok->[0] = 'IGNORE';				#ignore all to end bracket... but rewrite on exit from link
	push @returnstack, $tok;
    }
    return @returnstack;
}
 
sub _parsetable_simple {
    my @returnstack;
    my $intable=0;
    while (my $tok=shift @_) {
		if ( ref( $tok->[1] ) eq 'ARRAY')  {
		@{ $tok->[1] } = _parsetable_simple( @{ $tok->[1] } ) ; # dereference and recurse
	}

	if ($tok->[0] eq 'TABLE_C' and $intable) { # only if in table can we close
		$intable--;
	}
	if ($tok->[0] eq 'TABLE_O') {
	    $intable++;
	}
	$tok->[0]='IGNORE' if $intable or $tok->[0] eq 'TABLE_C' ; #ignore everything in table
	push @returnstack, $tok;
    }
    return @returnstack;
}

sub _parsetemplate_simple {
    my $templatedepth=0;
    my (@stack)=@_;
    my @returnstack;
    while (@stack) {
	my $tok = shift @stack;
	if ( ref( $tok->[1] ) eq 'ARRAY')  {
	    @{ $tok->[1] } = _parsetemplate_simple( @{ $tok->[1] } ) ; # dereference and recurse
	}

	my $this=$tok->[0];
	if ($this eq 'TEMPL_O') {
	    $templatedepth++;
	    $tok->[0]='IGNORE';
	    push @returnstack, $tok;
	    next
	};
	if ($this eq 'TEMPL_C') {
	    if ($templatedepth==0) {   # ignore close template if no prev. matching
		$tok->[0]='IGNORE'}
	    else { $templatedepth--; $tok->[0]='IGNORE'; }      # close if open ascend a level
	} elsif ($templatedepth!=0) {$tok->[0]='IGNORE';};
	push @returnstack, $tok;
    };
    return @returnstack;
}

sub reduce  {
    my (@stack)=@_;
    my @returnstack;
#     warn Dumper @stack;
#     my $leng =@stack;
#     say $leng;
    if (@stack >1) {
	my $tok= shift @stack;
	my $last=$tok->[0];
# 	say "$last:".$tok->[1];  
	if (ref($tok->[1]) eq 'ARRAY') {
	    @{ $tok->[1] } =reduce( @{ $tok->[1] } ); #dereference and 
# 	    say "recurse...";
	    $last="ARRAYREF";
	};
	my $this;
# 	say "Starting Reduction";
# 	warn Dumper $tok;
	push @returnstack, $tok;
	while ($tok=shift @stack) {
	    $this=$tok->[0];
# 	    say "$last:".$tok->[1], ref($tok->[1]);
# 	    say "this:$this: last:$last:";
	    if (ref($tok->[1]) eq 'ARRAY') {	# if ref then descend
		@{ $tok->[1] } =reduce( @{ $tok->[1] } ); # dereference and recurse
# 		say "recurse 2";
		$last="ARRAYREF";
	    };
	    if ($this eq $last and $last ne "ARRAYREF") {
		if (!defined $tok->[1])	{warn Dumper @returnstack; say "reduce Undefined tok problem!"; $tok->[1]=""; };
		#if (!defined $returnstack[-1]->[1]) {warn Dumper @returnstack };
		$returnstack[-1]->[1].=$tok->[1];  # don't merge array refs.
# 		say $returnstack[$#returnstack]->[0]." merging..." 
		next;
	    };
	push @returnstack, $tok;
# 	warn Dumper $tok;
	$last=$this;
	};
	return @returnstack;
    }
#    say "Reduction not needed - stack length ", @stack;
#     warn Dumper @stack;
    if (ref($stack[0]->[1]) eq 'ARRAY') {	# if ref then descend
		    @{ $stack[0]->[1] } =reduce( @{ $stack[0]->[1] } ); # dereference and recurse
    }
#     warn Dumper @stack;
    return @stack;
}

sub _simplify {
    my $groups=shift;
    #warn Dumper  $groups;
    $groups->{UNKNOWN} ||= 'UNKNOWN'; # a little sanity check - prevents undefs in stack that are hard to trace due to spelling mistakes!
    my @returnstack;
    while (my $tok=shift @_) {
	#say "processing ".$tok->[0];
	if ( !exists $groups->{$tok->[0]} ) {
	    say $tok->[0]." token was not found in simplify hash... Changed to UNKNOWN" if $debug; 
	    $tok->[0]='UNKNOWN';
	} 
	$tok->[0]=$groups->{$tok->[0]}; # use hash to simplify
	#if contains a ref - recurse into it...
	if ( ref( $tok->[1] ) eq 'ARRAY')  {
	    #say "descending to simplify array ref...";
	    @{ $tok->[1] } = _simplify( $groups , @{ $tok->[1] } ) ; # dereference and recurse
	    #say "coming back up";
	    #warn Dumper $tok;
	}
	#warn Dumper $tok;
	#say "   processed to ".$tok->[0];
	push @returnstack, $tok;   		# and return the renamed token
    }
    #warn Dumper @returnstack;
    return @returnstack;
};

sub flatten  {
    my (@stack) = @_;
    my @returnstack;
    while (my $tok = shift @stack) {
	if ( ref( $tok->[1] ) eq 'ARRAY' ) {
	    push @returnstack, [ $tok->[0],"" ];		# push marker token and empty string
	    push @returnstack, flatten( @{$tok->[1]} );# deref and recurse
	    next;
	}
    push @returnstack, $tok;
    }
    return @returnstack;
};

1;