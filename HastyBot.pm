#!/usr/bin/perl

package HastyBot;

use 5.10.1;
use warnings;
use strict;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

use LWP::Simple;
use MediaWiki::Bot;
use Data::Dumper::Simple;

# Version 1, 31/1/2010
# Script to get newest pages.
use Getopt::Long;
use Tie::File::AsHash;

BEGIN {
        use Exporter   ();
        our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
        # set the version for version checking
        $VERSION     = 0.99;
        @ISA         = qw(Exporter);
        @EXPORT      = qw();
        %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],
        # your exported package globals go here,
        # as well as any optionally exported functions
        @EXPORT_OK   = qw(%opts %seenpages &createbot &getpagelist &addtopage &ispageseen &purgepage &nextpage &getnextpage &savepage &markpageseen &getpage &getallpages);
    }
    our @EXPORT_OK;
# hastybot class - supersets wikipediabot class
# call -> new 
# CALL -> get opts - get command line
# CALL -> getpage (named page) - handles redirects (marks as seen) returns text of page
# CALL -> nextpage name - returns one by one, accepts array to add to stack 
# CALL -> savepage (named page, content, editcomment) unless simulated and cache
# CALL -> mark page seen (page, comment) 
# CALL -> ispageseen (page)
# CALL -> empty seen cache
# CALL -> findreplace regex,addtotop,addtobottom
# CALL -> getpagelist (new or all - given names space) but using cache - need empty first!
# CALL -> login - creates bot and logs in
# call -> getuserhastybotpage (hastybot/arconyms) get and parse a little - remove comments etc?
# call -> saveuserhastybotpage - put it back!

# define globals and tie's

tie our %hastybotconf, 'Tie::File::AsHash', 'HastyBot.conf', split => '~~~'
    or die "Problem tying %hastybotconf: $!"; # 1st
our %opts; # 2nd
getargs(); # 3rd

my $fn=$opts{botlogin}."-".$opts{wiki}."-seenpages.dat";
tie our %seenpages, 'Tie::File::AsHash', $fn, split => '~~~'
    or die "Problem tying %seenpages: $!"; # 4th

#warn Dumper %opts; 
#$opts{simulate}=1; $opts{verbose}=1; #emptycache();

say "(Debug mode enabled)"	    if $opts{debug};
say "(Simulate mode enabled)"   if $opts{simulate};
say "(Verbose mode selected)"   if $opts{verbose};

our $bot = MediaWiki::Bot->new('HastyBot'); 
createbot();
if ($opts{purge}) {purgepage ($opts{page})}; #only purge one page
getpagelist();


#### user functions here - poss using ($page,$edit)=getnextpage() ####

#what TODO about protected pages does/should hastybot have rights? Should there be a {{noRatingbar}} template or something?
#addtopage(qr/\{\{RatingBar\}\}/, "{{RatingBar}}\n","","Adding {{RatingBar}} to page");

##################################################################
END {
    say "\nHastyBot has finished and is going back to sleep..." if $opts{verbose};
    say "Done." if !$opts{verbose};
}

1;

#EXPORT
sub getargs { 
    my $help;
    # defaults
    %opts= (
    simulate 	=> '0',
    verbose	=> '0',
    debug	=> '0',
    namespace	=> 'main',
    wiki	=> 'www.ywamkb.net',
    prefix	=> 'kb',
    botlogin	=> '',
    botpass	=> '',
    action	=> 'nothing',
    whatpages	=> 'new',
    page	=> '',
    purge	=> '0',
    );

    foreach ( qw(wiki prefix botlogin botpass) )  {
	$opts{$_} = exists $hastybotconf{$_} ? $hastybotconf{$_} : $opts{$_};
    };
 
    usage() if ( ! GetOptions(\%opts,
	    'help|?', 
	    'simulate',
	    'verbose',
	    'debug',
	    'namespace:s',
	    'wiki:s',
	    'prefix:s',
	    'botlogin:s',
	    'botpass:s',
	    'action:s',
	    'whatpages:s',
	    'page:s',
	    'purge',
    ) or defined $help );
    
    if ($opts{whatpages} !~ m/^(all|new|allseen)$/) {die "$opts{whatpages} not supported: new, all (but not seen) allseen (all including seen)"};
    foreach ( qw(wiki prefix botlogin botpass) )  {
	$hastybotconf{$_}=$opts{$_}
    };
    if ($opts{debug}) {$opts{verbose}=1};
    #warn Dumper %hastybotconf;
};

sub usage  {
    say "Unknown option: @_\n" if ( @_ );
    say "usage: hastybot etc [--help|-?]";
    exit;
};

#EXPORT
sub ispageseen {
    my ($page)=@_;
#     say "$page in cache =".(defined $seenpages{$page});
#     warn Dumper %seenpages;
    return exists $seenpages{$page};
};

sub emptycache {
    %seenpages=();
};

#EXPORT
sub purgepage {
    say "Purging cache for page [[@_]]";
    return $bot->purge_page(@_);
}

#EXPORT
sub getpagelist {
    return nextpage("Sandbox") if $opts{debug};
    return nextpage($opts{whatpages} eq 'new' ? getnewestpages() : getallpages()) ;
}

sub getnewestpages {
    my ($namespace) =@_;
    $namespace ||= "main"; #default if none specified.
    say "Getting list of new pages from the wiki..." if $opts{verbose};
    # $i = get("http://www.ywamkb.net/kb/index.php/Special:NewPages"); #default is main namespace
    my $i = get("http://www.ywamkb.net/kb/index.php?title=Special:NewPages&namespace=$namespace");
    die "Couldn't get Special:NewPages." unless defined $i;

    my (@newestpages, $pagetitlere);
    $i=~ m/\<\!-- start content --\>(.*)\<\!-- end content --\>/s; if (defined($1)) {$i=$1}; #get rid of anything NOT article content <!-- end content -->#<!-- start content -->#
    #parse out the statistics we are looking for...
    # (.*?) is non greedy match everything... Just what is needed! (?: throw away capture
    $pagetitlere=qr/\<li\>(?:.*?)\>(.*?)\<\/a\>(?:.*?)\<\/li\>/; #set up a regex to search with

    while ($i=~ m/$pagetitlere/gcso) {
	my $found=$1;
	push @newestpages, $found; #build list of interesting pages
    };
    say "Got ",scalar @newestpages if $opts{verbose};
    return @newestpages;
};

sub getallpages {
    say "Getting ALL pages" if $opts{verbose};
    if ($opts{whatpages} eq "all") { emptycache() }; 
    my $namespace_id=0; #0=main # TODO
    my @pages=$bot->get_pages_in_namespace($namespace_id);
    say "Filtering ALL pages that are unseen already" if $opts{whatpages} eq 'allseen' && $opts{verbose};
    @pages = grep { !ispageseen($_)  } @pages;
    say scalar @pages, " pages listed" if $opts{verbose};
    return @pages;
    }

#EXPORT
{ my @nextpages;
sub nextpage {
    #warn Dumper @nextpages, @_;
    if (@_) {push @nextpages, (@_); say scalar @nextpages, " queued" if $opts{verbose}; return;} # add any arguments onto the list of pages and return doing nothing
    return pop @nextpages if @nextpages;     # if any items in array return the next one
    } 					     # otherwise, just return nothing
};

#EXPORT
sub createbot {
    say "\nWaking HastyBot and charging him with busy-work!" if $opts{verbose};
    $bot->set_wiki( $opts{wiki}, $opts{prefix} );
    if ($opts{botlogin} eq '') 		{ die "HastyBot needs a bot login. Specify with: HastyBot --botlogin=\n"; }
    if ($opts{botpass}  eq '') 		{ die "HastyBot needs a password. Specify with: HastyBot --botpass=\n";   }
    $bot->login( $opts{botlogin}, $opts{botpass} ) or die "Login failed";
    say " Logged in..." if $opts{verbose};
};

#EXPORT
sub addtopage {
    my ($addtore, $addtotop, $addtobottom, $comment)=@_;
    while (my ($page,$edit) = getnextpage()) {
    if ($edit!~ m/$addtore/os) {
	    #unless text is already there then edit and save
	    $edit=$addtotop.$edit.$addtobottom;
	    say "Match found: Adding TEXT to page [[$page]]";
	    savepage($page,$edit,$comment);
	} else {
	    say "Match found. Text already exists - nothing to do" if $opts{verbose}; 
	    markpageseen($page,"unmodified"); 
	};
    }
};

#EXPORT
sub getnextpage {
    my $ignoreseen='';
    if (@_) { $ignoreseen = shift };
    my $redirectloop=0;
    while (1) {
    my $page = nextpage(); 
    return if $page eq '0'; #quit because we are out of pages
    #check page has not already been seen
    if ($ignoreseen !~ /ignore\s*seen/i) {
	if (ispageseen($page)) {
	    say "[[$page]] already seen - skipping..." if $opts{verbose};
	    next;
	}
    }
    #check page has is not the Main Page
    if ($page eq "Main Page") {
	say "[[Main Page]] skipped as HastyBot avoids this page if $opts{verbose}";
	next;
    };

    say "\nRetrieving Page [[$page]]" if $opts{verbose};
    my $edit = $bot->get_text($page);
    die "Couldn't retrieve text of [[$page]]!" if (ref($edit) eq "SCALAR" && $edit==2);  #bomb out if error fetching...

    #check for redirects... #REDIRECT [[title]]
    if ($edit=~ m/^#REDIRECT \[\[(.*?)\]\]$/) {
	$redirectloop++;
	if ($redirectloop>10) {
	    say "Redirect loop detected after 10 redirects. Aborting...";
	    $redirectloop=0;
	    next;
	};
	markpageseen($page,"redirect");
	$page=$1;
	say "  Redirect found - searching for page [[$page]]" if $opts{verbose};
	redo; #start again with page as redirect
    };
    # TODO what about redirects that take you to a different namespace?
    return ($page,$edit);
    };
};

sub getpage {
    my ($page)=@_;
    die "No page given to sub getpage!" if !defined($page) ;
    say "\nRetrieving Page [[$page]]" if $opts{verbose};
    my $edit = $bot->get_text($page);
    die "Couldn't retrieve text of [[$page]]!" if (ref($edit) eq "SCALAR" && $edit==2);  #bomb out if error fetching...
    return $edit;
}
#EXPORT
sub savepage {
    my ($page, $edit, $comment) = @_;
    say "  Saving Page [[$page]]...";
    #if ($opts{debug}) {$page="User:HastyBot/Sandbox";}
    if (!$opts{simulate}) {
	my $result=$bot->edit($page,$edit,$comment,1);
	die "Problem saving page - edit not made." unless $result->{edit}{result} eq 'Success';
	say "  Done" if $opts{verbose};
	markpageseen($page,"modified");
	}
    else {say "(Save simulated)" if $opts{verbose}};    
};

#EXPORT
sub markpageseen {
    my ($page,$comment) = @_;
    $comment ||= 'seen';
    $seenpages{$page}=$comment;
};

# my $pagename="YWAMKnowledgeBase:Statistics"; #this is the page we want to edit
# my ($x,$i,$result);
#for testing...
# $i=q{
# <!-- start content -->
# <ul><li>09:14, 22 January 2010 ‎<a href="/kb/index.php?title=About_Youth_With_a_Mission&amp;redirect=no" title="About Youth With a Mission">About Youth With a Mission</a> (<a href="/kb/index.php?title=About_Youth_With_a_Mission&amp;action=history" title="About Youth With a Mission">hist</a>) ‎[76 bytes] ‎<a href="/kb/index.php/User:Kevin" title="User:Kevin" class="mw-userlink">Kevin</a>  <span class="mw-usertoollinks">(<a href="/kb/index.php?title=User_talk:Kevin&amp;action=edit&amp;redlink=1" class="new" title="User talk:Kevin (page does not exist)">Talk</a>&#32;|&#32;<a href="/kb/index.php/Special:Contributions/Kevin" title="Special:Contributions/Kevin">contribs</a>)</span>  <span class="comment">(clarity)</span> </li> 
# <li>09:13, 22 January 2010 ‎<a href="/kb/index.php?title=YWAM_Statement_of_Purpose&amp;redirect=no" title="YWAM Statement of Purpose">YWAM Statement of Purpose</a> (<a href="/kb/index.php?title=YWAM_Statement_of_Purpose&amp;action=history" title="YWAM Statement of Purpose">hist</a>) ‎[1,385 bytes] ‎<a href="/kb/index.php/User:Kevin" title="User:Kevin" class="mw-userlink">Kevin</a>  <span class="mw-usertoollinks">(<a href="/kb/index.php?title=User_talk:Kevin&amp;action=edit&amp;redlink=1" class="new" title="User talk:Kevin (page does not exist)">Talk</a>&#32;|&#32;<a href="/kb/index.php/Special:Contributions/Kevin" title="Special:Contributions/Kevin">contribs</a>)</span>  <span class="comment">(we didn&#39;t seem to have this)</span> </li> 
# <li>11:27, 21 January 2010 ‎<a href="/kb/index.php?title=User_%26_Rights_Management&amp;redirect=no" title="User &amp; Rights Management">User &amp; Rights Management</a> (<a href="/kb/index.php?title=User_%26_Rights_Management&amp;action=history" title="User &amp; Rights Management">hist</a>) ‎[21,617 bytes] ‎<a href="/kb/index.php/User:PitPat2" title="User:PitPat2" class="mw-userlink">PitPat2</a>  <span class="mw-usertoollinks">(<a href="/kb/index.php/User_talk:PitPat2" title="User talk:PitPat2">Talk</a>&#32;|&#32;<a href="/kb/index.php/Special:Contributions/PitPat2" title="Special:Contributions/PitPat2">contribs</a>)</span>  <span class="comment">(notes)</span> </li> 
# <li>20:58, 20 January 2010 ‎<a href="/kb/index.php?title=Staff_Fees&amp;redirect=no" title="Staff Fees">Staff Fees</a> (<a href="/kb/index.php?title=Staff_Fees&amp;action=history" title="Staff Fees">hist</a>) ‎[148 bytes] ‎<a href="/kb/index.php/User:Kevin" title="User:Kevin" class="mw-userlink">Kevin</a>  <span class="mw-usertoollinks">(<a href="/kb/index.php?title=User_talk:Kevin&amp;action=edit&amp;redlink=1" class="new" title="User talk:Kevin (page does not exist)">Talk</a>&#32;|&#32;<a href="/kb/index.php/Special:Contributions/Kevin" title="Special:Contributions/Kevin">contribs</a>)</span>  <span class="comment">(save)</span> </li> 
# <li>20:46, 20 January 2010 ‎<a href="/kb/index.php?title=Staff_Training_and_Development&amp;redirect=no" title="Staff Training and Development">Staff Training and Development</a> (<a href="/kb/index.php?title=Staff_Training_and_Development&amp;action=history" title="Staff Training and Development">hist</a>) ‎[3,104 bytes] ‎<a href="/kb/index.php/User:Kevin" title="User:Kevin" class="mw-userlink">Kevin</a>  <span class="mw-usertoollinks">(<a href="/kb/index.php?title=User_talk:Kevin&amp;action=edit&amp;redlink=1" class="new" title="User talk:Kevin (page does not exist)">Talk</a>&#32;|&#32;<a href="/kb/index.php/Special:Contributions/Kevin" title="Special:Contributions/Kevin">contribs</a>)</span>  <span class="comment">(save)</span> </li> 
# <li>09:01, 5 January 2010 ‎<a href="/kb/index.php?title=A_plea_for_Linux&amp;redirect=no" title="A plea for Linux">A plea for Linux</a> (<a href="/kb/index.php?title=A_plea_for_Linux&amp;action=history" title="A plea for Linux">hist</a>) ‎[1,940 bytes] ‎<a href="/kb/index.php/User:Pitpat" title="User:Pitpat" class="mw-userlink">Pitpat</a>  <span class="mw-usertoollinks">(<a href="/kb/index.php/User_talk:Pitpat" title="User talk:Pitpat">Talk</a>&#32;|&#32;<a href="/kb/index.php/Special:Contributions/Pitpat" title="Special:Contributions/Pitpat">contribs</a>)</span>  <span class="comment">(move article)</span> </li> 
# </ul>
# <!-- end content -->
# };

1;