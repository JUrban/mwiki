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
my $mml_dir;

sub set_MIZFILES {
  my $new_mizfiles = shift ();
  unless (-d $new_mizfiles) {
    croak ("The proposed new value for MIZFILES, \"$new_mizfiles\", is not a directory.");
  }
  my $new_mml_dir = $new_mizfiles . "/" . "mml";
  unless (-d $new_mml_dir) {
    croak ("It's required to have a subdirectory \"mml\" of MIZFILES");
  }
  $mizfiles = $new_mizfiles;
  $mml_dir = $new_mml_dir;
  return (1);
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
  for my $mizfile (qw/miz.xml mizar.dct mizar.msg mml.ini mml.lar mml.vct/) {
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
  my $new_mml = "$dir" . "/" . "mml";
  mkdir ($new_mml);

  # prel
  #
  # NOTE: we are putting the prel subdirectory UNDER mml/, NOT in the
  # toplevel MIZFILES directory.  In this respect, our newly
  # constructed MIZFILES differs from the MIZFILES in the official
  # mizar distro.
  my $real_prel_dir = $mizfiles . "/" . "prel";
  my $new_prel_dir = $new_mml . "/" . "prel";

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

sub symlink_clone_MIZFILES_in_dir {
  my $target_dir = shift;
  unless (-d $target_dir) {
    croak ("The given directory argument, $target_dir, isn't a directory!");
  }
  my $mizfiles = get_MIZFILES ();
  chdir ($mizfiles);
  my @dirs = `find . -type d`;
  my @files = `find . -type f`;
  my $cwd = getcwd ();
  chdir ($target_dir);
  foreach my $dir (@dirs) {
    chomp ($dir);
    `mkdir -p $dir`;
  }
  foreach my $file (@files) {
    chomp ($file);
    my $real_file = $mizfiles . "/" . $file;
    my $target_file = $target_dir . "/" . $file;
    # sanity check
    unless (-e $real_file) {
      croak ("Unable to link target file $target_file to source $real_file: the latter doesn't exist!");
    }
    symlink ($real_file, $target_file);
  }
  chdir ($cwd);
  return (0);
}

sub symlink_clone_MIZFILES_in_tempdir {
  my $temp = tempdir ();
  symlink_clone_MIZFILES_in_dir ($temp);
  return ($temp);
}

sub full_MIZFILES_in_dir {
  my $dir = shift ();
  my $cwd = getcwd ();
  sparse_MIZFILES_in_dir ($dir);
  my $real_mml_dir = get_MIZFILES () . "/" . "mml";
  my $new_mml_dir = $dir . "/" . "mml";
  chdir ($real_mml_dir);
  my @miz_files = `find . -type f -name "\*.miz"`;
  foreach my $miz_file (@miz_files) {
    chomp ($miz_file);
    my $real_miz_file_path = $real_mml_dir . "/" . $miz_file;
    unless (-e $real_miz_file_path) {
      croak ("Cannot symlink to a non-existent target: $real_miz_file_path");
    }
    my $new_miz_file_path = $new_mml_dir . "/" . $miz_file;
    symlink ($real_miz_file_path, $new_miz_file_path)
      or croak ("Something went wrong copying $real_miz_file_path to $new_miz_file_path: $!");
  }
  chdir ($cwd);
}

sub full_MIZFILES_in_tempdir {
  my $temp = tempdir ();
  full_MIZFILES_in_dir ($temp);
  return ($temp);
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

######################################################################
### Article dependencies
######################################################################

my $evl2txt = "/Users/alama/sources/mizar/xsl4mizar/evl2txt.xsl";

sub article_envget {
  my $article = shift ();
  my $envget_return = run_envget ($article);
  unless ($envget_return == 0) {
    croak ("Something went wrong running envget on $article!");
  }
}

sub article_evl2txt {
  my $article = shift ();
  article_envget ($article);
  my $article_evl = $mml_dir . "/" . $article . ".evl";
  my $article_dep = $mml_dir . "/" . $article . ".dep";
  unless (-e $article_evl) {
    croak ("The EVL file, $article.evl, doesn't exist under $mml_dir");
  }
  my $xsltproc_exit_status;
  system ("xsltproc", "--output", $article_dep, $evl2txt, $article_evl);
  $xsltproc_exit_status = ($? >> 8);
  unless ($xsltproc_exit_status == 0) {
    # Ditto.
    croak ("xsltproc did not exit cleanly when given $article_evl");
  }
}

sub article_proper_dependencies {
  my $article = shift ();
  # The "proper" dependencies of an article is the union of the
  # contents of all directives EXCEPT vocabularies.
  article_evl2txt ($article);
  # Parse the output from xsltproc generated by applying the evl2txt sheet.
  my ($dep_line, $semi_dep_line_field, $dep_line_field);
  my @dep_line_fields = ();
  my @article_notations = ();
  my @article_constructors = ();
  my @article_registrations = ();
  my @article_requirements = ();
  my @article_definitions = ();
  my @article_theorems = ();
  my @article_schemes = ();
  my $article_dep = $article . ".dep";
  my $article_dep_path = $mml_dir . "/" . $article_dep;
  my $article_dep_fh;
  open ($article_dep_fh, q{<}, $article_dep_path)
    or croak ("Unable to open article dependency file $article_dep_path!");
  while (defined ($dep_line = <$article_dep_fh>)) {
    chomp ($dep_line);
    # there's always a blank line at the end of the file -- yuck
    unless ($dep_line eq "") {
      push (@dep_line_fields, $dep_line);
    }
  }
  close ($article_dep_fh);
  foreach my $dep_line_field (@dep_line_fields) {
    # should look like (e.g.) "(vocabularies ...)".
    # First, delete the trailing ")"
    $dep_line_field = substr ($dep_line_field, 0, -1);
    # New get rid of the initial "(";
    $dep_line_field = substr ($dep_line_field, 1);
    my @dep_line_entries = split (/\ /x,$dep_line_field);
    my $first_element = shift (@dep_line_entries);

    if ($first_element eq "notations") {
      @article_notations = @dep_line_entries;
    }
    if ($first_element eq "constructors") {
      @article_constructors = @dep_line_entries;
    }
    if ($first_element eq "registrations") {
      @article_registrations = @dep_line_entries;
    }

    if ($first_element eq "requirements") {
      @article_requirements = @dep_line_entries;
    }
    if ($first_element eq "definitions") {
      @article_definitions = @dep_line_entries;
    }
    if ($first_element eq "theorems") {
      @article_theorems = @dep_line_entries;
    }
    if ($first_element eq "schemes") {
      @article_schemes = @dep_line_entries;
    }
  }

  my @article_deps_with_dups = (@article_notations,
				@article_constructors,
				@article_registrations,
				@article_requirements,
				@article_definitions,
				@article_theorems,
				@article_schemes);
  # Take out duplicates
  my @article_deps = ();
  my %article_deps_hash = ();
  foreach my $article (@article_deps_with_dups) {
    unless (defined ($article_deps_hash{$article})) {
      push (@article_deps, $article);
      $article_deps_hash{$article} = 0;
    }
  }

  return (\@article_deps);
}

sub mml_dependencies {
  my @mml_lar = get_MML_LAR ();
  my %dependencies = ();
  foreach my $article (@mml_lar) {
    my @depends = article_proper_dependencies ($article);
    $dependencies{$article} = \@depends;
  }
  return (%dependencies);
}

sub mml_dependencies_as_makefile_str {
  my @articles = mizar::get_MML_LAR ();
  my $makefile_str = "";
  $makefile_str .= ".PHONY: all xml html\n";
  $makefile_str .= "VPATH = mml\n";
  $makefile_str .= "XSLHOME = xsl\n";
  $makefile_str .= "ABSREFSXSL = \$(XSLHOME)/addabsrefs.xsl\n";
  $makefile_str .= "XML2HTML = \$(XSLHOME)/miz.xsl\n";
  $makefile_str .= "XSLTPROC = xsltproc\n";
  $makefile_str .= "MML = @articles\n";
  $makefile_str .= "xml: ";
  foreach my $article (@articles) {
    $makefile_str .=  $article . ".xml" . " ";
  }
  $makefile_str .= "\n";
  foreach my $article (@articles) {
    $makefile_str .= "$article.xml: $article.miz $article-prel\n";
    $makefile_str .= "\tmizf mml/$article.miz;\n";
  }

  # special: hidden-prel rule
  $makefile_str .= "hidden-prel:\n";
  $makefile_str .= "\ttouch mml/hidden-prel;\n";

  foreach my $article (@articles) {
    my @deps = @{article_proper_dependencies ($article)};
    $makefile_str .= "$article-prel: $article.miz ";
    foreach my $dep (@deps) {
      $makefile_str .= "$dep-prel ";
    }
    $makefile_str .= "\n";
    $makefile_str .= "\tmiz2prel mml/$article.miz;\n";
    $makefile_str .= "\ttouch mml/$article-prel;\n";
  }

  $makefile_str .= "\%-absrefs.xml: \%.xml\n";
  $makefile_str .= "\t\$(XSLTPROC) --output mml/\$*-absrefs.xml \$(ABSREFSXSL) mml/\$*.xml;\n";
  $makefile_str .= "html: \$(patsubst \%, \%.html, \$(MML))\n";
  $makefile_str .= "\tmkdir html;\n";
  $makefile_str .= "\%.html: \%-absrefs.xml\n";
  $makefile_str .= "\t\$(XSLTPROC) --output html/\$*.html \$(XML2HTML) mml/\$*-absrefs.xml;\n";

  return ($makefile_str);
}

1;
