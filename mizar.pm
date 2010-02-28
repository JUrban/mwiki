#!/usr/bin/perl -w

package Mizar;

use strict;
use warnings;
use Carp;

my $mizfiles = $ENV{"MIZFILES"}; # initial value comes from the environment
my $mizfiles_must_be_populated = 0;

sub require_properly_populated_mizfiles {
  $mizfiles_must_be_populated = 1;
}

sub permit_possibly_improperly_populated_mizfiles {
  $mizfiles_must_be_populated = 0;
}

sub properly_populated_mizfiles {
  my $proposed_mizfiles = shift ();
  return (1); # we can make this text more robust later
}

sub set_MIZFILES {
  my $new_mizfiles = shift ();
  if (-d $new_mizfiles) {
    if ($mizfiles_must_be_populated) {
      if (properly_populated_mizfiles ($new_mizfiles)) {
	$mizfiles = $new_mizfiles;
      } else {
	carp ("We are requiring MIZFILES to be properly populated, but the proposed new value for MIZFILES, \"$new_mizfiles\", is not properly populated.");
      }
    } else {
      warn ("MIZFILES is being set to \"$new_mizfiles\"; we didn't check whether it is properly populated.");
      warn ("Use this module at your own risk.");
    }
  } else {
    carp ("The proposed new value for MIZFILES, \"$new_mizfiles\", is not a directory.")
  }
  $mizfiles = $new_mizfiles;
}

sub get_MIZFILES {
  return ($mizfiles);
}

1;
