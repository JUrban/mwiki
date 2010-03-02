#!/usr/bin/perl -w

package mizar;

use strict;
use warnings;
use Carp;
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use File::Copy::Recursive qw/ dircopy /;
use File::Basename;
use Cwd;
use List::MoreUtils qw (any);

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
  return (@mml_lar);
}

sub copy_mizar_article_to_dir {
  my $article_id = shift;
  my $dir = shift;
  my $article_path = get_MIZFILES () . "/" . "mml" . "/" . $article_id . ".miz";
  unless (-d $dir) {
    croak ("Unable to copy $article_id to $dir because $dir isn't a directory!");
  }
  File::copy ($article_path, $dir) 
      or croak ("Something went wrong copying $article_id (more exactly, $article_path) to $dir");
}

sub sparse_MIZFILES_in_dir {
  my $dir = shift ();
  my $cwd = getcwd ();
  unless (-d $dir) {
    croak ("The given directory, $dir, isn't actually a directory");
  }
  my $mizfiles = get_MIZFILES ();

  # toplevel data
  copy ($mizfiles . "/" . "miz.xml", $dir);
  copy ($mizfiles . "/" . "mizar.dct", $dir);
  copy ($mizfiles . "/" . "mizar.msg", $dir);
  copy ($mizfiles . "/" . "mml.ini", $dir);
  copy ($mizfiles . "/" . "mml.lar", $dir);
  copy ($mizfiles . "/" . "mml.vct", $dir);

  # empty mml subdirectory
  mkdir ("$dir" . "/" . "mml");

  # prel
  my $real_prel_dir = $mizfiles . "/" . "prel";
  my $new_prel_dir = $dir . "/" . "prel";
  dircopy ($real_prel_dir, $new_prel_dir)
    or croak ("Error copying PREL directory: $!");

  return (0);
}

sub sparse_MIZFILES_in_tempdir {
  my $tempd = tempdir ();
  sparse_MIZFILES_in_dir ($tempd);
  return ($tempd);
}

sub copy_mml_to_dir {
  my $dir = shift ();
  unless (-d $dir) {
    croak ("The given directory, $dir, isn't actually a directory!");
  }
  my $temp_mml = "$dir/mml";
  mkdir ($temp_mml)
    or croak ("Unable to create the \"mml\" subdirectory of the temporary directory! $!");
  my $mizfiles = get_MIZFILES ();
  my @mml_lar = get_MML_LAR ();
  my $article_path;
  foreach my $mml_lar_entry (get_MML_LAR) {
    $article_path = "$mizfiles/mml/$mml_lar_entry.miz";
    copy ($article_path, $temp_mml)
      or croak ("Unable to copy the article $article_path to $temp_mml! $!");
  }
  return (1);
}

sub copy_mml_to_tempdir {
  my $cleanup = shift ();
  my $tempdir = tempdir (CLEANUP => $cleanup)
    or die ("Unable to create a temporary directory! $!");
  copy_mml_to_dir ($tempdir);
  return ($tempdir);
}

sub belongs_to_mml {
  my $article_id = shift ();
  my @mml = get_MML_LAR ();
  return (any { $_ eq $article_id } @mml);
}

# Running mizar programs in cutomizable ways

# Eventually we can adapt the parallelization code to carry out these
# tasks.

sub pad_mizfiles {
  my $pad = shift ();
  return (get_MIZFILES () . "$pad");
}

my $verifier_path;
my $accom_path;
my $makeenv_path;
my $exporter_path;

sub get_verifier_path {
  if (defined ($verifier_path)) {
    return ($verifier_path);
  }
  return (pad_mizfiles ("/" . "verifier"));
}

sub set_verifier_path {
  my $new_verifier_path = shift ();
  # is this for real?
  if (-x $new_verifier_path) {
    $verifier_path = $new_verifier_path;
    return (0);
  } else {
    warn ("The new proposed path for the verifier, $new_verifier_path, isn't executable.");
    return (-1);
  }
}

sub run_verifier {
  my $arg = shift ();
  my $base = basename ($arg, ".miz");
  my $error_file = $base . ".err";
  my $verifier = get_verifier_path ();

  my $cwd = getcwd ();

  chdir (get_MIZFILES ());
  system ("$verifier", "$arg");
  my $exit_status = ($? >> 8);
  chdir ($cwd);

  my $error_file_nonempty = (-e $error_file) && (!(-z $error_file));

  if ($exit_status == 0) {
    if ($error_file_nonempty) {
      return (-2)
    } else {
      return (0);
    }
  } else {
    return (-1);
  }

}

sub get_accom_path {
  if (defined ($accom_path)) {
    return ($accom_path);
  }
  return (pad_mizfiles ("/" . "accom"));
}

sub set_accom_path {
  my $new_accom_path = shift ();
  # is this for real?
  if (-x $new_accom_path) {
    $accom_path = $new_accom_path;
    return (0);
  } else {
    warn ("The new proposed path for the accom, $new_accom_path, isn't executable.");
    return (-1);
  }
}

sub run_accom {
  my $arg = shift ();
  my $base = basename ($arg, ".miz");
  my $error_file = $base . ".err";
  my $accom = get_accom_path ();

  my $cwd = getcwd ();

  chdir (get_MIZFILES ());
  system ("$accom", "$arg");
  my $exit_status = ($? >> 8);
  chdir ($cwd);

  my $error_file_nonempty = (-e $error_file) && (!(-z $error_file));

  if ($exit_status == 0) {
    if ($error_file_nonempty) {
      return (-2)
    } else {
      return (0);
    }
  } else {
    return (-1);
  }

}

sub get_makeenv_path {
  if (defined ($makeenv_path)) {
    return ($makeenv_path);
  }
  return (pad_mizfiles ("/" . "makeenv"));
}

sub set_makeenv_path {
  my $new_makeenv_path = shift ();
  # is this for real?
  if (-x $new_makeenv_path) {
    $makeenv_path = $new_makeenv_path;
    return (0);
  } else {
    warn ("The new proposed path for the makeenv, $new_makeenv_path, isn't executable.");
    return (-1);
  }
}

sub run_makeenv_in_dir {
  my $arg = shift;
  my $dir = shift;

  unless (-d $dir) {
    croak ("The given directory, $dir, isn't actually a directory");
  }

  my $base = basename ($arg, ".miz");
  my $error_file = $base . ".err";
  my $makeenv = get_makeenv_path ();

  my $cwd = getcwd ();

  chdir ($dir);
  my $old_mizfiles = $ENV{"MIZFILES"};
  my $new_mizfiles = get_MIZFILES ();
  $ENV{"MIZFILES"} = $new_mizfiles;
  system ("$makeenv", "$base.miz");
  $ENV{"MIZFILES"} = $old_mizfiles;
  my $exit_status = ($? >> 8);
  chdir ($cwd);

  my $error_file_nonempty = (-e $error_file) && (!(-z $error_file));

  if ($exit_status == 0) {
    if ($error_file_nonempty) {
      return (-2)
    } else {
      return (0);
    }
  } else {
    return (-1);
  }

}

sub run_makeenv {
  my $arg = shift;
  return (run_makeenv_in_dir ($arg, get_MIZFILES ()));
}

sub get_exporter_path {
  if (defined ($exporter_path)) {
    return ($exporter_path);
  }
  return (pad_mizfiles ("/" . "exporter"));
}

sub set_exporter_path {
  my $new_exporter_path = shift ();
  # is this for real?
  if (-x $new_exporter_path) {
    $exporter_path = $new_exporter_path;
    return (0);
  } else {
    warn ("The new proposed path for the exporter, $new_exporter_path, isn't executable.");
    return (-1);
  }
}

sub run_exporter_in_dir {

  my $arg = shift ();
  my $dir = shift ();

  unless (-d $dir) {
    croak ("The given directory in which to run exporter, $dir, isn't actually a directory");
  }

  my $base = basename ($arg, ".miz");
  my $error_file = $base . ".err";
  my $exporter = get_exporter_path ();

  my $cwd = getcwd ();

  chdir ($dir);

  my $old_mizfiles = $ENV{"MIZFILES"};
  my $new_mizfiles = get_MIZFILES ();
  $ENV{"MIZFILES"} = $new_mizfiles;
  system ("$exporter", "$base.miz");
  $ENV{"MIZFILES"} = $old_mizfiles;
  my $exit_status = ($? >> 8);
  chdir ($cwd);

  my $error_file_nonempty = (-e $error_file) && (!(-z $error_file));

  if ($exit_status == 0) {
    if ($error_file_nonempty) {
      return (-2)
    } else {
      return (0);
    }
  } else {
    return (-1);
  }

}

sub run_exporter {
  my $arg = shift ();
  return (run_exporter_in_dir ($arg, get_MIZFILES ()));
}

my $gxsldir = "";   	# set this eg. to some git of the xsl4mizar repo
my $gmizhtml = "";	# where are we linking to

# the stylesheets - might not exist, test with -e before using
my $addabsrefs = "$gxsldir/addabsrefs.xsl";
my $miz2html = (-e "$gxsldir/miz.xsl") ? "$gxsldir/miz.xsl" : "$gxsldir/miz.xml";

my $miz2html_params = "--param default_target \\\'_self\\\'  --param linking \\\'l\\\' --param mizhtml \\\'$gmizhtml\\\' --param selfext \\\'html\\\'  --param titles 1 --param colored 1 ";

sub htmlize
{
    my ($myfstem, $htmlize, $ajax_proofs, $ajax_proof_dir) = @_;
    if($htmlize == 2)
    {
	system("xsltproc $addabsrefs $myfstem.xml 2> $myfstem.xml.errabs > $myfstem.xml.abs");
	system("xsltproc $miz2html_params --param proof_links 1 --param ajax_proofs $ajax_proofs -param ajax_proof_dir \\\'$ajax_proof_dir\\\' $miz2html $myfstem.xml.abs 2>$myfstem.xml.errhtml > $myfstem.html");
    }
    elsif($htmlize == 1)
    {
	system("xsltproc $miz2html_params $miz2html $myfstem.xml 2>$myfstem.xml.errhtml > $myfstem.html");
    }    
}




1;
