package mizar;

## ubuntu packages required:
## REQ: libfile-copy-recursive-perl
## REQ: liblist-moreutils-perl

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


# run in the quite mode - default 1
my $gquiet = 1;
my $gquietflag = $gquiet ? ' -q ' : '';

# accept longlines - default 1
my $glonglines = 1;
my $glflag = $glonglines ? ' -l ' : '';


# hash of paths to the tools
my %toolpath = ();

# hash of flags of the tools
my %toolflags =
    (
     'exporter', 	" $glonglines $gquietflag ",
     'verifier', 	" $glonglines $gquietflag ",
     'makeenv', 	"",
     'accom',		""
    );




# toplevel files in the mml distro
my @mml_toplevel_files = ("miz.xml", "mizar.dct", "mizar.msg", "mml.ini", "mml.lar", "mml.vct");

# extensions of the environmental files
my @gaccexts = (".aco", ".atr", ".dct", ".dfs", ".eid", ".ere", ".esh", ".evl", ".frm", ".prf", ".vcl",
	       ".ano", ".cho", ".dcx", ".ecl", ".eno", ".eth", ".fil", ".nol", ".sgl");

# extensions of files created/used by verifier, with exception of the .xml file 
my @gvrfexts = ('.frx', '.idx', '.miz', '.par', '.ref');


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
  unless (-d $new_mizfiles) {
    croak ("The proposed new value for MIZFILES, \"$new_mizfiles\", is not a directory.");
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

  # toplevel data
  my $mizfiles = get_MIZFILES ();
  foreach my $mizfile (@mml_toplevel_files) {
#  for my $mizfile (qw/miz.xml mizar.dct mizar.msg mml.ini mml.lar mml.vct/) {
    my $real_mizfile = $mizfiles . "/" . $mizfile;
    unless (-e $real_mizfile) {
      croak ("Unable to link to a non-existent target: $real_mizfile");
    }
    my $linked_mizfile = $dir . "/" . $mizfile;
    if (-e $linked_mizfile) {
      croak ("Unwilling to overwrite an existing link");
    }
    symlink ($real_mizfile, $linked_mizfile);
  }

  # empty mml subdirectory
  mkdir ("$dir" . "/" . "mml");

  # prel
  my $real_prel_dir = $mizfiles . "/" . "prel";
  my $new_prel_dir = $dir . "/" . "prel";

  mkdir ($new_prel_dir);

  # hidden
  my $real_hidden_dco = $real_prel_dir . "/" . "h" . "/" . "hidden.dco";
  unless (-e $real_hidden_dco) {
    croak ("Unable to link to non-existent target: $real_hidden_dco");
  }
  my $linked_hidden_dco = $new_prel_dir . "/" . "hidden.dco";
  my $real_hidden_dno = $real_prel_dir . "/" . "h" . "/" . "hidden.dno";
  unless (-e $real_hidden_dno) {
    croak ("Unable to link to non-existent target: $real_hidden_dno");
  }
  my $linked_hidden_dno = $new_prel_dir . "/" . "hidden.dno";
  symlink ($real_hidden_dco, $linked_hidden_dco);
  symlink ($real_hidden_dno, $linked_hidden_dno);

  # tarski
  my $real_tarski_dco = $real_prel_dir . "/" . "t" . "/" . "tarski.dco";
  my $real_tarski_def = $real_prel_dir . "/" . "t" . "/" . "tarski.def";
  my $real_tarski_dno = $real_prel_dir . "/" . "t" . "/" . "tarski.dno";
  my $real_tarski_sch = $real_prel_dir . "/" . "t" . "/" . "tarski.sch";
  my $real_tarski_the = $real_prel_dir . "/" . "t" . "/" . "tarski.the";
  unless (-e $real_tarski_dco) {
    croak ("Unable to link to non-existent target: $real_tarski_dco");
  }
  unless (-e $real_tarski_def) {
    croak ("Unable to link to non-existent target: $real_tarski_def");
  }
  unless (-e $real_tarski_dno) {
    croak ("Unable to link to non-existent target: $real_tarski_dno");
  }
  unless (-e $real_tarski_sch) {
    croak ("Unable to link to non-existent target: $real_tarski_sch");
  }
  unless (-e $real_tarski_the) {
    croak ("Unable to link to non-existent target: $real_tarski_the");
  }
  symlink ($real_tarski_dco, $new_prel_dir . "/" . "tarski.dco");
  symlink ($real_tarski_def, $new_prel_dir . "/" . "tarski.def");
  symlink ($real_tarski_dno, $new_prel_dir . "/" . "tarski.dno");
  symlink ($real_tarski_sch, $new_prel_dir . "/" . "tarski.sch");
  symlink ($real_tarski_the, $new_prel_dir . "/" . "tarski.the");

  # requirements:
  my $real_hidden_dre = $real_prel_dir . "/" . "h" . "/" . "hidden.dre";
  my $real_boole_dre = $real_prel_dir . "/" . "b" . "/" . "boole.dre";
  my $real_subset_dre = $real_prel_dir . "/" . "s" . "/" . "subset.dre";
  my $real_arithm_dre = $real_prel_dir . "/" . "a" . "/" . "arithm.dre";
  my $real_numerals_dre = $real_prel_dir . "/" . "n" . "/" . "numerals.dre";
  my $real_real_dre = $real_prel_dir . "/" . "r" . "/" . "real.dre";

  unless (-e $real_hidden_dre) {
    croak ("Unable to link to non-existent target: $real_hidden_dre");
  }
  unless (-e $real_boole_dre) {
    croak ("Unable to link to non-existent target: $real_boole_dre");
  }
  unless (-e $real_subset_dre) {
    croak ("Unable to link to non-existent target: $real_subset_dre");
  }
  unless (-e $real_arithm_dre) {
    croak ("Unable to link to non-existent target: $real_arithm_dre");
  }
  unless (-e $real_numerals_dre) {
    croak ("Unable to link to non-existent target: $real_numerals_dre");
  }
  unless (-e $real_real_dre) {
    croak ("Unable to link to non-existent target: $real_real_dre");
  }

  symlink ($real_hidden_dre, $new_prel_dir . "/" . "hidden.dre");
  symlink ($real_boole_dre, $new_prel_dir . "/" . "boole.dre");
  symlink ($real_subset_dre, $new_prel_dir . "/" . "subset.dre");
  symlink ($real_arithm_dre, $new_prel_dir . "/" . "arithm.dre");
  symlink ($real_numerals_dre, $new_prel_dir . "/" . "numerals.dre");
  symlink ($real_real_dre, $new_prel_dir . "/" . "real.dre");

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

# Running mizar programs in customizable ways

# Eventually we can adapt the parallelization code to carry out these
# tasks.

sub pad_mizfiles {
  my $pad = shift ();
  return (get_MIZFILES () . "$pad");
}

my $verifier_path;
my $accom_path;
my $envget_path;
my $makeenv_path;
my $exporter_path;
my $mizf_path;

sub which {
  my $program = shift ();
  my $location = `which $program`;
  chomp ($location);
  return ($location);
}

sub get_verifier_path {
  if (defined ($verifier_path)) {
    return ($verifier_path);
  }
  return (which ("verifier"));
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

## todo: replace with run_mizar_tool('verifier', $arg), and remove the redundant stuff
sub run_verifier {
  my $arg = shift ();
  my $base = basename ($arg, ".miz");
  my $error_file = $base . ".err";
  my $verifier = get_verifier_path ();

  my $cwd = getcwd ();

  chdir (get_MIZFILES ());
  system ("$verifier $glflag $gquietflag $arg");
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

sub get_mizf_path {
  if (defined ($mizf_path)) {
    return ($mizf_path);
  }
  return (which ("mizf"));
}

sub set_mizf_path {
  my $new_mizf_path = shift ();
  # is this for real?
  if (-x $new_mizf_path) {
    $mizf_path = $new_mizf_path;
    return (0);
  } else {
    warn ("The new proposed path for the mizf, $new_mizf_path, isn't executable.");
    return (-1);
  }
}

sub run_mizf_in_dir {
  my $arg = shift;
  my $dir = shift;
  my $base = basename ($arg, ".miz");
  my $miz = $base . ".miz";
  my $error_file = $base . ".err";
  my $mizf = get_mizf_path ();

  my $cwd = getcwd ();

  chdir ($dir);
  system ($mizf, $miz);
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

sub run_mizf {
  my $arg = shift ();
  return (run_mizf_in_dir ($arg, get_MIZFILES () . "/" . "mml"));
}

sub get_accom_path {
  if (defined ($accom_path)) {
    return ($accom_path);
  }
  return (which ("verifier"));
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

## TODO: replace with run_mizar_tool('accom', $arg), and remove the redundant stuff
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
  return (which ("makeenv"));
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

## TODO: replace with run_mizar_tool('makeenv', $arg), and remove the redundant stuff
sub run_makeenv {
  my $arg = shift;
  return (run_makeenv_in_dir ($arg, get_MIZFILES ()));
}

sub get_envget_path {
  if (defined ($envget_path)) {
    return ($envget_path);
  }
  return (which ("envget"));
}

sub set_envget_path {
  my $new_envget_path = shift ();
  # is this for real?
  if (-x $new_envget_path) {
    $envget_path = $new_envget_path;
    return (0);
  } else {
    warn ("The new proposed path for the envget, $new_envget_path, isn't executable.");
    return (-1);
  }
}

sub run_envget_in_dir {
  my $arg = shift;
  my $dir = shift;

  unless (-d $dir) {
    croak ("The given directory, $dir, isn't actually a directory");
  }

  unless (-w $dir) {
    croak ("One cannot write to the given directory, $dir");
  }

  my $base = basename ($arg, ".miz");
  my $miz = $base . ".miz";
  my $error_file = $base . ".err";
  my $envget = get_envget_path ();

  my $cwd = getcwd ();

  my $old_mizfiles = $ENV{"MIZFILES"};
  $ENV{"MIZFILES"} = get_MIZFILES ();
  chdir ($dir);
  system ($envget, $miz);
  my $exit_status = ($? >> 8);
  $ENV{"MIZFILES"} = $old_mizfiles;
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

sub run_envget {
  my $arg = shift;
  return (run_envget_in_dir ($arg, get_MIZFILES () . "/" . "mml"));
}

sub get_exporter_path {
  if (defined ($exporter_path)) {
    return ($exporter_path);
  }
  return (which ("exporter"));
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
  system ("$exporter $glonglines $gquietflag $base.miz");
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

## TODO: replace with run_mizar_tool('exporter', $arg), and remove the redundant stuff
sub run_exporter {
  my $arg = shift ();
  return (run_exporter_in_dir ($arg, get_MIZFILES ()));
}




## TODO: binaries should be assumed to be in $MIZFILES/bin, either change this or the pad function
sub get_tool_path {
  my ($tool) = @_;
  if (defined ($toolpath{$tool})) {
    return ($toolpath{$tool});
  }
  return (pad_mizfiles ("/" . $tool));
}

sub set_tool_path
{
    my ($tool, $new_tool_path) = @_;
    # is this for real?
    if (-x $new_tool_path) {
	$toolpath{$tool} = $new_tool_path;
	return (0);
    } else {
	warn ("The new proposed path for the $tool, $new_tool_path, isn't executable.");
	return (-1);
    }
}

sub run_tool_in_dir {
    my ($tool, $arg, $dir) = @_;

    unless (-d $dir) 
    {
	croak ("The given directory in which to run $tool, $dir, isn't actually a directory");
    }

  my $base = basename ($arg, ".miz");
  my $error_file = $base . ".err";
  my $tool_path = get_tool_path($tool);
  my $tool_flags = $toolflags{$tool};

  my $cwd = getcwd ();

  chdir ($dir);

  my $old_mizfiles = $ENV{"MIZFILES"};
  my $new_mizfiles = get_MIZFILES ();
  $ENV{"MIZFILES"} = $new_mizfiles;
  system ("$tool_path $tool_flags $base.miz");
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







# Run a Mizar tool on an argument file in a suitable way
sub run_mizar_tool {
    my ($tool, $arg) = @_;
    return (run_tool_in_dir ($tool, $arg, get_MIZFILES ()));
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
