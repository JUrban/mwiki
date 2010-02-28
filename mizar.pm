#!/usr/bin/perl -w

package Mizar;

use strict;
use warnings;
use Carp;
use File::Temp qw/ tempfile tempdir /;
use File::Copy;

my $mizfiles;
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
  unless (defined ($mizfiles)) {
    $mizfiles = $ENV{"MIZFILES"};
  }
  return ($mizfiles);
}

my @mml_lar;
my $num_mml_lar_entries = 0;

sub initialize_mml_lar {
  my $mml_lar_path = get_MIZFILES () . "/" . "mml.lar";
  my $mml_lar_fh;
  open ($mml_lar_fh, q{<}, $mml_lar_path)
    or croak ("Unable to open $mml_lar_path!");
  push (@mml_lar, "tarski");
  $num_mml_lar_entries++;
  my $mml_lar_line;
  while (defined ($mml_lar_line = <$mml_lar_fh>)) {
    chomp ($mml_lar_line);
    push (@mml_lar, $mml_lar_line);
    $num_mml_lar_entries++;
  }
}

sub get_MML_LAR {
  if ($num_mml_lar_entries == 0) {
    initialize_mml_lar ();
  } 
  return (\@mml_lar);
}

sub copy_mml_to_tempdir {
  my $cleanup = shift ();
  my $tempdir = tempdir (CLEANUP => $cleanup)
    or die ("Unable to create a temporary directory! $!");
  my $temp_mml = "$tempdir/mml";
  mkdir ($temp_mml)
    or croak ("Unable to create the \"mml\" subdirectory of the temporary directory! $!");
  my $mizfiles = get_MIZFILES ();
  my @mml_lar = get_MML_LAR ();
  my $article_path;
  foreach my $mml_lar_entry (@mml_lar) {
    $article_path = "$mizfiles/mml/$mml_lar_entry.miz";
    copy ($article_path, $temp_mml)
      or croak ("Unable to copy the article $article_path to $temp_mml! $!");
  }
  return ($tempdir);
}

1;
