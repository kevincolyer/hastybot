#!/usr/bin/perl

use 5.10.0;
use warnings;
use strict;

use Data::Dumper::Simple;

package Kpctools;
 
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
our $VERSION     = 0.99;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw(commify);
#our %EXPORT_TAGS = ( DEFAULT => [qw(&XXX &XXX &XXX &XXX) ] );

sub commify {
   my $input = shift;
   $input = reverse $input;
   $input =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   $input = reverse $input;
   return $input;
}
#return one as we are a package
1;
