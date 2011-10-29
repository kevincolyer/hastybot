#!/usr/bin/perl

use 5.10.1;
use strict;
# licence - perl artistic licence...
use utf8;
use warnings FATAL => qw(uninitialized);
binmode STDOUT, ":encoding(UTF-8)";
# use Data::Dumper::Simple;
# use lib "/home/kevin/Dropbox/development/modules";

package MediaWikiParser;
 
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw(tokenise parse rendertext rendertokens renderhtml debug timed customparser flatten mergetokens make_iterator);

our $debug=0;
our $timed=0;
our $debugtokens=0;

sub value 	($)  { return $_[0]->[1] 	};
sub setvalue 	($$) { return $_[0]->[1]=$_[1]  };
sub token 	($)  { return $_[0]->[0] 	};
sub settoken 	($$) { return $_[0]->[0]=$_[1]  };

# alternate tokeniser that pre-processes handles the html comments and nowiki and noincludes as done in the real MW parser. Should make logic in the tokenise function easier (and some of the expensive searches - such as urls and mailtos - my addition) 
# sub tokenise2 {
#   my $text = shift;
#   return ( ['IGNORE', ''] ) if !defined $text; # case of null input
#   return ( ['IGNORE', ''] ) if $text eq "";    # case of null input
#   my @stream=preprocess($text);
#   return @stream = grep{ tokenise(value $_) if token $_ eq 'UNTOKENISED'} @stream;
# }
# 
# sub preproces {
#     my $text=shift;
#     my @stream=(['UNTOKENISED',$text]);
#     my @gstream;
#     # handle htmlcomments (first)
#     @stream=grep { 
#       $text= value $_;
#       @gstream=();
#       while ($text =~ m/(?!<!--)(<!--.*?-->)(.*)/) {
#         push @gstream, ['UNTOKENISED',$1],['HTMLCOM',$2];
#         $text=$3;
#       }
# As a workaround for this problem, Perl 5.10.0 introduces ${^PREMATCH} , ${^MATCH} and ${^POSTMATCH} , which are equivalent to $` , $& and $' , except that they are only guaranteed to be defined after a successful match that was executed with the /p (preserve) modifier. The use of these variables incurs no global performance penalty, unlike their punctuation char equivalents, however at the trade-off that you have to tell perl when you want to use them. 
#       push @gstream, ['UNTOKENISED',$text];
#     } @stream;
#     return ['HTMLCOM_O',   $1]  if $text =~ /\G (<!--)          /gcx;
#     return ['HTMLCOM_C',   $1]  if $text =~ /\G (-->)           /gcx;
#     # handle nowwiki
#     return ['NOWIKI_O',    $1]      if $text =~ /\G (<nowiki>|<NOWIKIKI>)   /gcx;
#     return ['NOWIKI_C',    $1]  if $text =~ /\G (<\/nowiki>|<\/NOWIKI>) /gcx;
#             #       'HTMLCOM'
#     # handle noincludes
#     # handle URL and MAILTO
#     return @stream;
# }
sub tokenise {
    my ($text) = @_;
    return ( ['IGNORE', ''] ) if !defined $text; # case of null input
    return ( ['IGNORE', ''] ) if $text eq ""; 	 # case of null input
    my @stream ;
    my $state_nowiki=0;
    my $state_htmlcom=0;
    # my @state_html; # state variable is a stack... perhaps we need a stack here too?

    #study $text;
    my $tokens = sub {
	TOKEN: { 
	    #	    'URL'
	    # http regexp inspiration from http://www.wellho.net/resources/ex.php4?item=p212/regextra
	    # tokenise some code and inspiration from MJD's Higher Order Perl...
	    # MJD says that the i mod tends to disable optimisations - hence extra patterns below... (http://perl.plover.com/yak/regex/samples/slide080.html) - seems to work well - now 0.8s to 0.65 ish...
 
	    return ['WS', 	   $1]	if $text =~ /\G (\h+)		/gcx; # \h is horiz ws = space tab but not newline

	    return ['MAILTO',      $1] 	if $text =~ /\G (
                                                        (?:mailto\:|MAILTO\:)
                                                        (?:\/\/)?		# optional
                                                        (?:[^\s]+)		# before @
                                                        (?:\@)			# must have an @
                                                        (?:(?:[^\s\]\.\}])+)	# atleast one word
                                                        (?:\.(?:[^\s\]\}])+)?	# optional . and word
                                                        )		/gcx;
	    return ['URL',         $1] 	if $text =~ /\G (
							(?:http|https|ftp|HTTP|HTTPS|FTP)
							(?:\:\/\/)  
							(?:[^\:\/\s\]\}]+)      # server
							(?:\:\d+)?              # port - optional
							(?:\/[^\#\s\]\}]+)?     # page - optional
							(?:[\/|\#](?:[^\]\}|\S]*))?          # place - optional need ] here?
								)	/gcx;

	    return ['BODYWORD',    $1] 	if $text =~ /\G (\w+)		/gcx;
	    return ['MAGICWORD',   $1] 	if $text =~ /\G	(__[A-Z]+__)	/gcx;
	    
	    return ['POINT',       $1] 	if $text =~ /\G (\.)		/gcx;
	    return ['COLON',       $1] 	if $text =~ /\G (:)		/gcx;
	    return ['SEMICOLON',   $1] 	if $text =~ /\G (;)		/gcx;
	    return ['EXCLAMATION', $1] 	if $text =~ /\G (!)		/gcx;
	    return ['BOLD',	   $1]  if $text =~ /\G (''')		/gcx;
	    return ['ITALIC',	   $1]  if $text =~ /\G ('')		/gcx;
	    return ['APOSTROPHY',  $1]  if $text =~ /\G (')		/gcx;
	    return ['ASTERISK',    $1] 	if $text =~ /\G (\*)		/gcx;   # need m for multiline to enable anchors here...
	    return ['HASH',        $1] 	if $text =~ /\G (\#)		/gcx;   # need m for multiline to enable anchors here...
	    
	    return ['BODYWORD',    $1]  if $text =~ /\G ([," \? \( \)]) /gcx;   # catch all for optimisation sake - common punc that falls through

	    return ['NL',          $1]	if $text =~ /\G (\n+)		/gcx; # put above whites space
	    return ['HEADING_C',   $1] 	if $text =~ /\G (={1,6})	/gcx; # heading_o below...
	   
	    return ['NBSP',	   $1] 	if $text =~ /\G	(\&nbsp;)	/gcx;
	    return ['NOWIKI_O',    $1] 	if $text =~ /\G	(<nowiki>|<NOWIKIKI>)	/gcx;
	    return ['NOWIKI_C',    $1] 	if $text =~ /\G	(<\/nowiki>|<\/NOWIKI>)	/gcx;
	    #       'HTMLCOM'
	    return ['HTMLCOM_O',   $1] 	if $text =~ /\G	(<!--)		/gcx;
	    return ['HTMLCOM_C',   $1] 	if $text =~ /\G	(-->)		/gcx;
	    #	    'TABLE'
	    return ['TABLE_O',     $1]	if $text =~ /\G (\{\|)		/gcx;
	    return ['TABLE_C', 	   $1]	if $text =~ /\G (\|\})		/gcx; # because |}} bar/templ_e is confused with table_c|ignore...
	    #	    'BODYTEXT'
	    return ['BAR',         $1] 	if $text =~ /\G (\|)		/gcx; # because |}} bar/templ_e is confused
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

	    return ['PRE_O',       $1] 	if $text =~ /\G	(<pre>|<PRE>)		/gcx;
	    return ['PRE_C',       $1] 	if $text =~ /\G	(<\/pre>|<\/PRE>)	/gcx;
	    #	    'HTML'
	    return ['BR',          $1] 	if $text =~ /\G	(<br\/?>|<BR\/?>)	/gcx;  
	    return ['HR',          $1] 	if $text =~ /\G	(<hr\/?>|<HR\/?>)	/gcx;  
	    return ['HTML_SINGLE', $1]	if $text =~ /\G(<\w*\/?>)	/gcx;
	    return ['HTML_O',      $1] 	if $text =~ /\G	(<\w+.*?>)	/gcx;
	    return ['HTML_C',      $1] 	if $text =~ /\G	(<\/\w*>)	/gcx;

	    return ['UNKNOWN',     $1] 	if $text =~ /\G (.)		/gcx;
	    
	    return undef;
	}
    };

    my ($this, $last);
    $last="n/a";
    _time("starting tokeniser") if $timed;
    my $tok;
    while ($tok = $tokens->() ) {
	# comments 
	# opening and closing comments
	# $state_nowiki $state_htmlcom
	# htmlcomments 
# 	say $tok->[0]," " x (20-length($tok->[0])),"| ".$tok->[1] if $debugtokens;
 	say token $tok," " x (20-length(token $tok)),"| ".value $tok if $debugtokens;
#	settoken $tok => "BOBBLE";
#	do {print token $tok; say value $tok} if $debugtokens;
	
	if (token $tok eq 'HTMLCOM_O') {
	    if   ( $state_nowiki  or  $state_htmlcom ) 	
		 { settoken $tok => 'IGNORE' }
	    else { $state_htmlcom = 1; settoken $tok => 'IGNORE' } 
	};
	if (token $tok eq 'HTMLCOM_C') {
	    if   ( $state_nowiki  or !$state_htmlcom ) 	
		 { settoken $tok => 'IGNORE' }
	    else { $state_htmlcom = 0; settoken $tok => 'IGNORE' }  
	};
	# nowiki tags can be thrown away 
	if (token $tok eq 'NOWIKI_O') {
	    if   ( $state_nowiki  or  $state_htmlcom ) 
		 { settoken $tok =>  'IGNORE' }
	    else { $state_nowiki = 1; settoken $tok => 'IGNORE' } 
	};
	if (token $tok eq 'NOWIKI_C') {
	    if   ( !$state_nowiki or  $state_htmlcom ) 
		 { settoken $tok => 'IGNORE' }
	    else { $state_nowiki = 0; settoken $tok =>  'IGNORE' }
	};

	settoken $tok => 'IGNORE' if $state_htmlcom;  # if in a comment - mark text as ignored... 
	settoken $tok => 'NOWIKI' if $state_nowiki>1; # if in a nowiki mark as NOWIKI for user to do what they want with it
	$state_nowiki++ if $state_nowiki; # TODO why is this here?
	# now comments are done we can get on with some other things and not worry them

	# TODO - inside html....
	# HTML_BODY	=> 'IGNORE',

	$this = token $tok;
	# warn "UNKNOWN token encountered |".$tok->[1]".| following |$last|" if ($this eq 'UNKNOWN' and $debug);
	# process HEADINGS - moved to _parseheading
		
	if ($last eq "NL") { # this logic is faster than RE with m modifier... MUCH - saves >50% ? - could try with nl[\*])
	    settoken $tok => 'BULLET' 	  if $this eq 'ASTERISK';
	    settoken $tok => 'NUMLIST'    if $this eq 'HASH';
	    settoken $tok => 'HEADING_O'  if $this eq 'HEADING_C';
	    settoken $tok => 'PRE_SINGLE' if $this eq 'WS'; # NOTE WS can contain multplie spaces - pre is one following NL
	}

	# some optimisation to mergetokens tokens
	if ( $this eq $last && ($this eq 'UNKNOWN' or $this eq 'IGNORE' )) { # or $this eq 'WS'
	    $stream[-1][1].= value $tok;
	    next;
	}
        push @stream, $tok;
	$last = $this;
    }
    _time("finishing tokeniser",-1) if $timed;
    #warn Dumper @stream;
    if ($stream[0][0] eq "HEADING_C") {$stream[0][0]="HEADING_O"} # because lexer only emit's HEADING_O...
    return @stream;
}

###############################################################
sub rendertext {
    local $_= _render("" ,1,@_);
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

sub renderhtml {
    _time("starting renderhtml") if $timed;
    push my @stream ,   @_  ;
    my $text="";
#say "in _render - initial stack is...";
#warn Dumper @stream;
    my $it = walkstream( \@stream ) ;
    my ($tok,$t);
    while ($tok = NEXTVAL($it)) {
#	warn Dumper $tok;
	#next if @{$tok}==0;
	if (ref( $tok->[1] ) eq 'ARRAY') {
	    # nothing for nowiki
	    # $text.=$tok->[0] if $which==0; 	# if rendering tokens(=0) then we want to see the token of array ref
	    $t="";
	} else {
	    given (token $tok) {
		when ('BOLD')		{ state $tog=1; $tog=!$tog; $t= (!$tog) ? '<b>' : '</b>'  };
		when ('ITALIC')		{ state $tog=1; $tog=!$tog; $t= (!$tog) ? '<i>' : '</i>'  };
		when ('BULLET')		{ state $tog=1; $tog=!$tog; $t= (!$tog) ? '<li>' : '</li>'  };
		#when ('BODYWORD')	{ $t= '<p>'. ( value $tok ) ."</p>\n"  };
		default  		{ $t= value $tok };
	    }
	}
	$text.=$t;
    }
    _time("finished rendertml",-1) if $timed;
    return $text;    
}

sub rendertokensbartext {
    use Kpctools q<snippet>;
    my (@stream, $text, $first, $len);
    @stream=@_;
    $text="";
    while (my $tok = shift @stream) {
	$text.="\n" if $first++;
	if (ref( $tok->[1] ) eq 'ARRAY') {
	    $text.="\n".$tok->[0].":\n"; 			# because we want to see the token
	    $text.=rendertokensbartext( @{ $tok->[1] } ); 	# recurse on dereferenced array
	    $text.="\n"; 					# show the tokens are a group.
	} else {
	    $len= " " x ( 20-length( $tok->[0] ) );
	    $text.=$tok->[0].$len.$tok->[1];			# .snippet( $tok->[1] , 60);
	}
    }
    return $text;
}

sub _render {
    _time("starting _render") if $timed;

    my ($text, $first);
    my $join= shift @_;
    my $which= shift @_;
    push my @stream ,   @_  ;
    $text="";
#say "in _render - initial stack is...";
#warn Dumper @stream;
    my $it = walkstream( \@stream ) ;
    my $tok;
    while ($tok = NEXTVAL($it)) {
#	warn Dumper $tok;
	#next if @{$tok}==0;
	$text.=$join if $first++;
	if (ref( $tok->[1] ) eq 'ARRAY') {
	    $text.=$tok->[0] if $which==0; 	# if rendering tokens(=0) then we want to see the token of array ref
	} else {
	    $text.= $tok->[$which];
	}
    }
    _time("finished _render",-1) if $timed;
    return $text;
}

###############################################################
sub parse {
    #simple parser
    #return _testparser(tokenise(@_));
    return _testparser(@_);
}
    
sub make_iterator {
    my (@stream) = @_  ; 
    return Iterator {
	return undef if !@stream; 	# if nothing more return undef
	return shift @stream ; 		# otherwise return a token and mergetokens stack
	}
}

sub customparser {
    _time("--ignore--",0) if $timed;
    _time("starting custom parser") if $timed;

    my ($wikitext,$o1,$o2, @parsers)=@_;
    $wikitext="" if !defined $wikitext; # case of null input
    # tokenising
    my @stream=	tokenise($wikitext);

    # continue parsing using chain of sub parsers, including custom parsers if reqd.
    _time("starting chained subparsers") if $timed;
    if (!@parsers) { @parsers = qw(_parseheading _parsetemplate_simple _parseelink _parseilink_simple _parsetable_simple) };
    no strict; 					# needed for below
    map { @stream =  &$_(@stream) } @parsers; 	# &$_() creates a sub from the string value in $_
    use strict;
    _time("finishing chained subparsers",-1) if $timed;
    
    # optimise 					#1 - group tokens, two passes
#     _simplify($o1, \@stream);
#     _simplify($o2, \@stream); # new version is 40ms slower than old!
    @stream = _simplify_old($o1, @stream);
    @stream = _simplify_old($o2, @stream);


    # optimise 					#2 - combine adjacant identical tokens
    @stream=	mergetokens(@stream);
#     warn Dumper @stream;    
    # sanity check - if parser fails we want to make sure we don't mess up on live wiki's
    if (rendertext(@stream) ne $wikitext) { 
#	warn Dumper @stream;
	die "Rendering comparison of parsed wikitext failed - critical error. Stopping."; 
    }

    _time("finished custom parser",-1) if $timed;
    return @stream;
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

	BOLD 		=> 'BOLD', 		#in this case   
	ITALIC 		=> 'ITALIC', 		#in this case	   
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
			_parsetemplate_ignore 
			_parseelink
			_parseilink_simple
			_parsetable_simple	);
    return customparser(@_, \%o1, \%o2, @parsers); #calling like this not good - implicit assumption that first arg is scalar ($wikitext)
}

sub _parseheading { 
    my @returnstream;
    my $state_heading=0;
    my $headinglevel=0;
    my $last ='n/a';
# warn Dumper @_;
    while (my $tok=shift @_) {
# 	warn Dumper $tok;
	if ( ref( $tok->[1] ) eq 'ARRAY')  {
		@{ $tok->[1] } = _parseheading( @{ $tok->[1] } ) ; # dereference and recurse
	}

	if ($tok->[0] eq 'NL' and $headinglevel) {$headinglevel=0; $returnstream[$state_heading]->[0]='IGNORE'; $state_heading=0}; # reset heading on newline

	if ($tok->[0] eq 'HEADING_O') { # heading OPEN
	    if ($headinglevel) {die ("this can not happen - heading_o is always first!");}
	    $headinglevel = length ($tok->[1]);
	    $state_heading 	  = @returnstream; # stack pos +1 = size will be the index of this item as not inserted into stack yet!
	    $tok->[0]     = "H$headinglevel";
	};

	if ($tok->[0] eq 'HEADING_C') { # heading CLOSE
	    if (!$headinglevel) {$tok->[0] = 'IGNORE'} # ignore close before open
	    else {
		my $closeheading=length($tok->[1]); 
		if ($headinglevel>$closeheading) { # closeheading wins - add an ignore with = x diff after openheading
		    my $tok2 = ['IGNORE','=' x ($headinglevel-$closeheading)];
		    splice(@returnstream,$state_heading+1,0,$tok2); #hopefully add tok2 to just after the first heading
		    $returnstream[$state_heading]->[0]= "H$closeheading";
		    $returnstream[$state_heading]->[1]= "=" x $closeheading;
		    $tok->[0]="H$closeheading";
		}; 
		if ($headinglevel<$closeheading) { # heading wins - add and ignore with = x diff after close heading - reset closeheading
		    $last='IGNORE'; # we move ahead a token so trick optimiser...
		    my $tok2 = [$last,'=' x ($closeheading-$headinglevel)];
		    push @returnstream,$tok2; # push my difference token into stack before current token 
		    $tok->[0]= "H$headinglevel";
		    $tok->[1]= "=" x $headinglevel;
		    $closeheading=$headinglevel;
		    
		}; 
		if ($closeheading==$headinglevel) { # the only other option...
		    $tok->[0] = "H$closeheading";
		};
		# cut out the heading, replace with arrayref and tok h3 etc.
		my @snip= splice (@returnstream, $state_heading);
		#warn Dumper @snip;
		# ignore opening tag and closing semantic meaning no longer neaded
		$snip[0]->[0] = 'IGNORE';
		$tok->[0] = 'IGNORE';
		push @snip, $tok; # put closing tag on too i.e. currently processing one
		#warn Dumper @snip;
		$returnstream[$state_heading]->[1]= \@snip;			# add array ref to stack
		$returnstream[$state_heading]->[0] = "H$closeheading";	# give it a meaningful name
		#warn Dumper @stream;
		# done
		$headinglevel=0;
		$last='IGNORE';
		$state_heading=0;
		
		next; # we've added to stack so now restart the loop.
	    }
	}
	push @returnstream, $tok;
    }
    #warn Dumper @returnstream;
    return @returnstream;
}



sub _parseelink { 
    my @returnstream;
    my $state_elink=0;
    my $elinkstart=0;
    my $elinkurl = 0;
    my $elinkws=0;
    while (my $tok=shift @_) {
	if ( ref( $tok->[1] ) eq 'ARRAY')  {
		@{ $tok->[1] } = _parseelink( @{ $tok->[1] } ) ; # dereference and recurse
	}

	#if url not in elink then mark as bareurl or baremailto
	#if in an elink then elink-url seek comment, seek white space... mark as elink-comment
	if (!$state_elink) { # NOT In an ELINK
	    $tok->[0] = 'BARE'.$tok->[0] if ($tok->[0] eq 'URL' or $tok->[0] eq 'MAILTO'); 
	    $tok->[0] = 'IGNORE' 	 if  $tok->[0] eq 'ELINK_C';  # mistake - not in link and so ignore tag
	    if ($tok->[0] eq 'ELINK_O') {
		$elinkstart=@returnstream;
		$state_elink=1;
	    }
	    #say "not in elink: ",$tok->[0],$tok->[1];
	    push @returnstream, $tok; # nothing to see move along please!
	    next;
	}

	if ($state_elink) {
	    die "in an elink and found another elink open tag - don;t know what to do. :-(" if $tok->[0] eq 'ELINK_O';
	    
	    if ($tok->[0] eq 'URL' or $tok->[0] eq 'MAILTO') {
		$tok->[0] = 'ELINKCOMMENT' 	if $elinkurl; # ne ''; # multiple url's are comments...'
		$elinkurl = 1 ;#		if $elinkurl eq '';
	    }

	    if ($tok->[0] eq 'WS') {
		if ($elinkws==0) {
		    $elinkws=@returnstream; 	# only record first ws seen...
		}			 	# mark WS as IGNORE later
	    }

	    if ($tok->[0] eq 'NL') {
		#reset
# 		for ($elinkstart..@returnstream) {
# 		    $returnstream[$_]->[0]='IGNORE';
# 		}
		$elinkstart=0;
		$state_elink=0;
		$elinkws=0;
		$elinkurl=0;
	    }
	    
	    if ($tok->[0] eq 'ELINK_C') {
		if ($elinkws) {
		    for ($elinkws+1..@returnstream-1) {
			$returnstream[$_]->[0] = 'ELINKCOMMENT';
		    }
		}
		$returnstream[$elinkstart]->[0] = 'IGNORE';
		$returnstream[$elinkws]->[0] = 'IGNORE';
		$returnstream[$elinkstart+1]->[0] = 'ELINK'.$returnstream[$elinkstart+1]->[0];
		$elinkstart=0;
		$elinkws=0;
		$elinkurl=0;
		$state_elink=0;
		$tok->[0]='IGNORE';
	    }
	}
	#say " in elink: ",$tok->[0],$tok->[1];
	push @returnstream, $tok;
    }
    if ($state_elink) {
	for ($elinkstart..@returnstream) {
	    $returnstream[$_]->[0]='IGNORE';
	}
    }
    #rendertokens(@returnstream);
    #warn Dumper @returnstream;
    return @returnstream;
}
 
sub _parseilink_simple {
    my $open=0;
    my $inilink=0;
    my $firstbar=0;
    my $lastbar=0;
    my @returnstream;
    while (my $tok=shift @_) {
	if ( ref( $tok->[1] ) eq 'ARRAY')  {
		@{ $tok->[1] } = _parseilink_simple( @{ $tok->[1] } ) ; # dereference and recurse
	}

	if ($inilink==0) { 					# if we are not in a link...
	    if ($tok->[0] eq 'ILINK_C') {$tok->[0]='IGNORE'};   # if close before open ignore
	    if ($tok->[0] eq 'ILINK_O') {			# mark opening of elink
		$open=@returnstream;
		#say "open @ $open";
		$inilink=1;
		$firstbar=0;
	        $lastbar=0;
	    }; # ILINK_O ================= END
	    push @returnstream, $tok; 				# anything else drops through...
	    next;
	} 

	# we are in a link...
	if ($tok->[0] eq 'NL') { # NL ==== END			# if eol then Ilink should be ignored... 
	    $returnstream[$open]->[0]='IGNORE'; 
	    $inilink=0;						# mark as not in link
	    push @returnstream, $tok;
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
		    $returnstream[$_]->[0]='ILINK_PAGE';
		}
		if ($lastbar) {
		    #say "starting rewitre of ilink_comment";
		    for ($lastbar+1..@returnstream-1) {
			#say $_;
			$returnstream[$_]->[0]='ILINK_COMMENT';
		    }
		}
	    } else { 
		#say "no bars encountered...";
		for ($open+1..@returnstream-1) {
		    #say $_;
		    $returnstream[$_]->[0]='ILINK_PAGE';
		    }
	    };
	    #say "ending rewrite and closing the ilink";
	    $open=0; 
	    $inilink=0;
	    push @returnstream, $tok;
	    next;
	} ; # ILINK_C =====END		
	    # BAR ============
	if ($tok->[0] eq 'BAR') {
	    $firstbar=@returnstream if !$firstbar;	# before is ILINK_PAGE # TODO is this assumption true?
	    $lastbar =@returnstream if  $firstbar;	# last is ILINK_COMMENT
	    $tok->[0]='IGNORE';				# ignore BAR now please
	    #say "first bar $firstbar, last bar $lastbar";
	    push @returnstream, $tok;
	    next;
	}; # BAR ==========END
	$tok->[0] = 'IGNORE';				#ignore all to end bracket... but rewrite on exit from link
	push @returnstream, $tok;
    }
    return @returnstream;
}
 
sub _parsetable_simple {
    my @returnstream;
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
	push @returnstream, $tok;
    }
    return @returnstream;
}

sub _parsetemplate_simple {
    my $templatedepth=0;
    my (@stream)=@_;
    my @returnstream;
    while (@stream) {
	my $tok = shift @stream;
	if ( ref( $tok->[1] ) eq 'ARRAY')  {
	    @{ $tok->[1] } = _parsetemplate_simple( @{ $tok->[1] } ) ; # dereference and recurse
	}

	my $this=$tok->[0];
	if ($this eq 'TEMPL_O') {
	    $templatedepth++;
	    $tok->[0]='IGNORE';
	    push @returnstream, $tok;
	    next
	};
	if ($this eq 'TEMPL_C') {
	    if ($templatedepth==0) {   # ignore close template if no prev. matching
		$tok->[0]='IGNORE'}
	    else { $templatedepth--; $tok->[0]='IGNORE'; }      # close if open ascend a level
	} elsif ($templatedepth!=0) {$tok->[0]='TEMPLATE';};
	push @returnstream, $tok;
    };
    return @returnstream;
}

sub _parsetemplate_ignore {
    my $templatedepth=0;
    my (@stream)=@_;
    my @returnstream;
    while (@stream) {
	my $tok = shift @stream;
	if ( ref( $tok->[1] ) eq 'ARRAY')  {
	    @{ $tok->[1] } = _parsetemplate_simple( @{ $tok->[1] } ) ; # dereference and recurse
	}

	my $this=$tok->[0];
	if ($this eq 'TEMPL_O') {
	    $templatedepth++;
	    $tok->[0]='IGNORE';
	    push @returnstream, $tok;
	    next
	};
	if ($this eq 'TEMPL_C') {
	    if ($templatedepth==0) {   # ignore close template if no prev. matching
		$tok->[0]='IGNORE'}
	    else { $templatedepth--; $tok->[0]='IGNORE'; }      # close if open ascend a level
	} elsif ($templatedepth!=0) {$tok->[0]='IGNORE';};
	push @returnstream, $tok;
    };
    return @returnstream;
}
sub mergetokens  { # merges two identical tokens into one token
    _time("starting mergetokens") if $timed;
#     if (@_ == 1) { 
# 	_time("finishing mergetokens - short stack",-1) if $timed;
# 	return @_
#     }
#     my (@stream)=@_;
    my $last="n/a";
    my $this;
    my @returnstream;
    my $tok;
#     warn Dumper @stream;
#     my $leng =@stream;
#     say $leng;
    
    while ($tok=shift @_) {
	if (!defined $tok->[1])	{
# 	    warn Dumper @returnstream, $tok; 
	    say "mergetokens Undefined payload tok [1] problem!"; 
	    $tok->[1]="";
	};
	    
# 	    say "$last:".$tok->[1], ref($tok->[1]);
# 	    say "this:$this: last:$last:";
	if (ref($tok->[1]) eq 'ARRAY') {	# if ref then descend
	    @{ $tok->[1] } =mergetokens( @{ $tok->[1] } ); # dereference and recurse
# 		say "recurse 2";
	    $last="ARRAYREF"; # don't merge array refs.
	    push @returnstream, $tok;
	    next;
	};
	$this=$tok->[0];
	if ($this eq $last and $last ne "ARRAYREF") {
	    #if (!defined $returnstream[-1]->[1]) {warn Dumper @returnstream };
	    $returnstream[-1][1].= $tok->[1];  
#  		say $returnstream[-1][0]." merging..."; 
	    next;
	};
	push @returnstream, $tok;
# 	warn Dumper $tok;
	$last=$this;
    };
    _time("finishing mergetokens",-1) if $timed;
    return @returnstream;
} # old was 470535 to 436,569 = 35k..........now 460821 to 449214 = 11K


sub NEXTVAL 	{ $_[0]->() 	}
sub Iterator (&){ return $_[0] 	}

sub walkstream ($) {
    my $streamref =  shift @_ ;
# warn Dumper $streamref;
    die 'Not an array ref in @streams' if ref ($streamref) ne "ARRAY";
    my $index = 0;
    my $length=scalar @{$streamref};
    #die 'in walk stream - $length is set to '.$length;
    push my @streams , $streamref, $index, $length; # push in triples in to @streams
    my $tok;
    return Iterator {
# warn Dumper @streams;
	while (@streams) {
	    $index = $streams[1]; 
# # say scalar @streams, " index=$index length=$length";
	    #if (!defined $length) {say  'in walkstream $length was not defined'; die } #Dumper @streams};
	    if ($index >= $streams[2]) {shift @streams; shift @streams; shift @streams; next;} 	# remove exhausted iterator
	    $tok = $streams[0][$index]; 							# get next token
	    $streams[1]++ ; 									# increment the index
# warn Dumper $tok;
	    #die '$tok does not have two entries in array' if scalar @{$tok} != 2;
	    if (ref($tok->[1]) eq 'ARRAY') {unshift @streams, $tok->[1],0,scalar @{$tok->[1]} } # put the next array on bottom of stack
	    return $tok;
	}
    return undef ; # exhausted iterator returns nothing...
    }
}

# sub walkstream (\@) { #note  as of now this eats the incoming stream...
#     my @streamref = @_;
#     push my @streams , walkarray ( @streamref ) ; # only 1 ref coming in
#     die 'Not a code ref in @streams' if ref (@streams[0]) ne "CODE";
#     return Iterator {
#        say "in walkstream iterator: ", scalar @streams, " arrayrefs in @ streams...";
# 	while (@streams) { 
# 	    my $tok = $streams[0]->(); # get next val from 1st iterator in queue
# 	    warn Dumper $tok;
# 	    if (!defined $tok) {shift @streams; next;} # end of iterator, get new one
# 	    if (ref ($tok->[1]) eq 'ARRAY') {unshift @streams, walkarray( $tok->[1] )}; # it is a new level so unshift it and work on new level next time
# 	    say scalar @{$tok}, " tok length";
# 	    return $tok;
# 	}
#     return undef;
#     }
# }
# 
# sub walkarray (\@) {
#     no strict; 
#     my $array1= \@_;
#     my $array = $array1->[0];
#     warn Dumper $array;
#     die 'Not an array ref in @streams' if ref ($array) ne "ARRAY";
#     my $index=0;
#     return Iterator {
# 	say $index, " ", scalar @{$array}, " ", $array->[$index];
# 	return $array->[$index++] if $index< scalar @{$array};
# 	return undef;
#     }
# }



sub _simplify {
        _time("starting simplify") if $timed;
    my $groups=shift;
    my $stream=shift;
    #warn Dumper  $groups;
    $groups->{UNKNOWN} ||= 'UNKNOWN'; # a little sanity check - prevents undefs in stack that are hard to trace due to spelling mistakes!
    my $it = walkstream ( $stream );
    
    while (my $tok = $it->() ) {
	#say "processing ".$tok->[0];
	if ( !exists $groups->{$tok->[0]} ) {
	    say $tok->[0]." token was not found in simplify hash... Changed to UNKNOWN" if $debug; 
	    $tok->[0]='UNKNOWN';
	} 
	$tok->[0]=$groups->{$tok->[0]}; # use hash to simplify
    }
    _time("finishing simplify",-1) if $timed;
    return  
};

sub _simplify_old {
        _time("starting simplify_old") if $timed;
    my $groups=shift;
    #warn Dumper  $groups;
    $groups->{UNKNOWN} ||= 'UNKNOWN'; # a little sanity check - prevents undefs in stack that are hard to trace due to spelling mistakes!
    my @returnstream;
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
	    @{ $tok->[1] } = _simplify_old( $groups , @{ $tok->[1] } ) ; # dereference and recurse
	    #say "coming back up";
	    #warn Dumper $tok;
	}
	#warn Dumper $tok;
	#say "   processed to ".$tok->[0];
	push @returnstream, $tok;   		# and return the renamed token
    }
    #warn Dumper @returnstream;
    _time("finishing simplify_old",-1) if $timed;

    return @returnstream;
};
sub flatten  {
       _time("starting flatten") if $timed;

    my @returnstream;
    my $it = walkstream( \@_ ) ;

    while (my $tok = $it->() ) {
	if ( ref( $tok->[1] ) eq 'ARRAY' ) { push @returnstream, [$tok->[0], ""] ; next } # if you do $tok->[1]="" you clobber the array and break the iterator as it works by reference passing atm.
	push @returnstream, $tok;
    }
#     warn Dumper @returnstream;
    _time("finishing flatten",-1) if $timed;
    return @returnstream;
}; # iterator makes flatten 10K slower?

############### for timings ##############################################

use Time::HiRes qw(tv_interval gettimeofday);
use Kpctools qw(commify);

BEGIN { my $t0 = [gettimeofday]; my $indent=0; my $rt=0;
 sub _time {
    my $comment= shift;
    if ($comment eq "--ignore--") {$rt=0;};
    if (@_) {$indent += shift @_} else {$indent++};
    my $intv=tv_interval($t0, [gettimeofday])*1000000;
    $rt+=$intv;
    say ":" x $indent."$comment ".commify($intv)," Time elapsed (rt) = ".commify($rt);;
    $t0=[gettimeofday];
} 
}


1;