#!/usr/bin/perl

use 5.10.0;
use warnings;
use strict;

use LWP::Simple;
use MediaWiki::Bot;
use Data::Dumper::Simple;

# Version 1, 31/1/2010
# Script to get newest pages.
use Getopt::Long;
use Tie::File::AsHash;

# hastybot class - supersets wikipediabot class
# call -> new 
# CALL -> get opts - get command line
# call -> get page (named page)
# call -> next page - generates one by one -1==error, 0==finished. Handles redirects 
# CALL -> set page (named page, content, editcomment) unless simulated and cache
# CALL -> mark page seen (page, comment) 
# CALL -> ispageseen (page)
# CALL -> empty seen cache
# call -> findreplace regex,addtotop,addtobottom
# call -> get page list (new or all - given names space) but using cache - need empty first!

# define globals
tie our %hastybotconf, 'Tie::File::AsHash', 'HastyBot.conf', split => '~~~'
    or die "Problem tying %hastybotconf: $!";
our %opts;

getargs() ;

my $fn=$opts{botlogin}."-".$opts{wiki}."-seenpages.dat";
say $fn;
tie our %seenpages, 'Tie::File::AsHash', $fn, split => '~~~'
    or die "Problem tying %seenpages: $!";

warn Dumper %opts; #$opts{simulate}=1; #emptycache();

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
	    'whatpages:s'
    ) or defined $help );
    #warn Dumper %opts; 
    if ($opts{whatpages} !~ m/^(all|new|allseen)$/) {die "$opts{whatpages} not supported: new, all (but not seen) allseen (all including seen)"};
    foreach ( qw(wiki prefix botlogin botpass) )  {
	$hastybotconf{$_}=$opts{$_}
    };
    #warn Dumper %hastybotconf;
};

sub usage  {
    print "Unknown option: @_\n" if ( @_ );
    print "usage: hastybot etc [--help|-?]\n";
    exit;
};

sub ispageseen {
    my ($page)=@_;
#     say "$page in cache =".(defined $seenpages{$page});
#     warn Dumper %seenpages;
    return exists $seenpages{$page};
};

sub emptycache {
    %seenpages=();
};

my @newestpages=getnewestpages("main");

say for @newestpages;

sub getnewestpages {
    my ($namespace) =@_;
    $namespace ||= "main"; #default if none specified.
    print "Getting list of new pages from the wiki...\n";
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
	say "[[$found]]";
	push @newestpages, $found; #build list of interesting pages
    };
    return @newestpages;
};


#Creating BOT and logging in...
print "\nWaking HastyBot and charging him with busy-work!\n";
my $bot = MediaWiki::Bot->new('HastyBot'); 
$bot->set_wiki($opts{wiki},$opts{prefix});
if ($opts{botlogin} eq '') {die "HastyBot needs a bot login. Specify with HastyBot --botlogin=ReallyHastyBot"; }
if ($opts{botpass} eq '') {die "HastyBot needs a password. Specify with HastyBot --botpass=secret"; }
$bot->login($opts{botlogin},$opts{botpass}); 
print " Logged in...\n";
###########################################do something with newest pages################

my ($addtotop, $addtore,$addtobottom, $page,$edit,$redirectloop);
$addtore=qr/\{\{RatingBar\}\}/;
my $texttoadd="{{RatingBar}}";
$addtotop="$texttoadd\n"; #add a newline as it keeps the headings happy. 
$addtobottom="";
$redirectloop=0;

@newestpages=("Sandbox") if $opts{debug};

for my $page (@newestpages) {
    #Retrieve page from the wiki
    if (ispageseen($page)) {
	say "[[$page]] already seen - skipping...";
	next;
    }

    if ($page eq "Main Page") {
	say "[[Main Page]] skipped as HastyBot avoids this page";
	next;
    };

    print "Retrieving Page [[$page]]\n";
    $edit=$bot->get_text($page);
    die "Couldn't retrieve text of [[$page]]!" if (ref($edit) eq "SCALAR" && $edit==2);  #bomb out if error fetching...

    #check for redirects... #REDIRECT [[title]]
    if ($edit=~ m/^#REDIRECT \[\[(.*?)\]\]$/) {
	$redirectloop++;
	if ($redirectloop>10) {
	print "Redirect loop detected after 10 redirects. Aborting...\n";
	$redirectloop=0;
	next;
	};
	$page=$1;
	print "  Redirect found - searching for page [[$1]]\n";
	markpageseen($page,"redirect");
	redo; #start again with page as redirect #warning - what if we ecounter a forever loop?
	};
    $redirectloop=0;

    #MAKE THE EDIT
    if ($edit!~ m/$addtore/os) {
	#unless text is already there then edit and save
	#check here for namespace?????
	$edit=$addtotop.$edit.$addtobottom;
	print "Match found: Adding TEXT to page.\n";
	savepage($page,$edit,"Adding $texttoadd to page");
    } else {
	print "Match found. Text already exists - nothing to do\n"; 
	markpageseen($page,"unmodified"); 
    };

};

sub savepage {
    my ($page, $edit, $comment) = @_;
    print "  Saving Page [[$page]]... \n";
    #if ($opts{debug}) {$page="User:HastyBot/Sandbox";}
    if (!$opts{simulate}) {
	my $result=$bot->edit($page,$edit,$comment,1);
	die "Problem saving page - edit not made." unless $result->{edit}{result} eq 'Success';
	print "  Done\n";
	markpageseen($page,"modified");
	}
    else {say "(Save simulated)"};    
};

sub markpageseen {
    my ($page,$comment) = @_;
    $comment ||= 'seen';
    $seenpages{$page}=$comment;
};
say "my work here is done...";
my $pagename="YWAMKnowledgeBase:Statistics"; #this is the page we want to edit
my ($x,$i,$result);
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