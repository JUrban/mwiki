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
 my $mml_dir;
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
 my @mml_toplevel_files = ("mizar.dct", "mizar.msg", "mml.ini", "mml.lar", "mml.vct");

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
   my $new_mml = "$dir" . "/" . "mml";
   mkdir ($new_mml);

   # prel
   #
   # NOTE: we are putting the prel subdirectory UNDER mml/, NOT in the
   # toplevel MIZFILES directory.  In this respect, our newly
   # constructed MIZFILES differs from the MIZFILES in the official
   # mizar distro.
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

   # # tarski
   # my $real_tarski_dco = $real_prel_dir . "/" . "t" . "/" . "tarski.dco";
   # my $real_tarski_def = $real_prel_dir . "/" . "t" . "/" . "tarski.def";
   # my $real_tarski_dno = $real_prel_dir . "/" . "t" . "/" . "tarski.dno";
   # my $real_tarski_sch = $real_prel_dir . "/" . "t" . "/" . "tarski.sch";
   # my $real_tarski_the = $real_prel_dir . "/" . "t" . "/" . "tarski.the";
   # unless (-e $real_tarski_dco) {
   #   croak ("Unable to link to non-existent target: $real_tarski_dco");
   # }
   # unless (-e $real_tarski_def) {
   #   croak ("Unable to link to non-existent target: $real_tarski_def");
   # }
   # unless (-e $real_tarski_dno) {
   #   croak ("Unable to link to non-existent target: $real_tarski_dno");
   # }
   # unless (-e $real_tarski_sch) {
   #   croak ("Unable to link to non-existent target: $real_tarski_sch");
   # }
   # unless (-e $real_tarski_the) {
   #   croak ("Unable to link to non-existent target: $real_tarski_the");
   # }
   # symlink ($real_tarski_dco, $new_prel_dir . "/" . "tarski.dco");
   # symlink ($real_tarski_def, $new_prel_dir . "/" . "tarski.def");
   # symlink ($real_tarski_dno, $new_prel_dir . "/" . "tarski.dno");
   # symlink ($real_tarski_sch, $new_prel_dir . "/" . "tarski.sch");
   # symlink ($real_tarski_the, $new_prel_dir . "/" . "tarski.the");

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
   my $makefile_str = <<"END_MAKE_BEFORE_DEPS";
 .PHONY: all xml html
 VPATH = mml
 XSLHOME = xsl
 ABSREFSXSL = \$(XSLHOME)/addabsrefs.xsl
 XML2HTML = \$(XSLHOME)/miz.xsl
 XSLTPROC = xsltproc
 MML = @articles
 xml: \$(patsubst \%, \%.xml, \$(MML))
 \%.xml: \%.miz \%-prel
	 mizf mml/\$*.miz;
 \%-absrefs.xml: \%.xml
	 \$(XSLTPROC) --output mml/\$*-absrefs.xml \$(ABSREFSXSL) mml/\$*.xml;
 html: \$(patsubst \%, \%.html, \$(MML))
	 mkdir html;
 \%.html: \%-absrefs.xml
	 \$(XSLTPROC) --output html/\$*.html \$(XML2HTML) mml/\$*-absrefs.xml;
 hidden-prel:
	 touch mml/hidden-prel;
END_MAKE_BEFORE_DEPS
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
   return ($makefile_str);
 }

 my %mizar_errors = 
   (1 => 'It is not true',
    4 => 'This inference is not accepted',
    8 => 'Too many instantiations',
    9 => 'Too many instantiations',
    10 => 'Too many basic sentences in an inference',
    11 => 'Too many constants in an inference',
    12 => 'Too long universal prefix',
    13 => 'Too many complexes',
    14 => 'Too many terms in an inference',
    15 => 'Too many equalities in an inference',
    16 => 'Collection overflow',
    20 => 'The structure of the sentences disagrees with the scheme',
    21 => 'Invalid instantiation of a scheme functor',
    22 => 'Invalid instantiation of a scheme predicate',
    23 => 'Invalid order of arguments in the instantiated predicate',
    24 => 'Instantiations of the same scheme predicate do not match',
    25 => 'Instantiations of the same scheme constant do not match',
    26 => 'Substituted constant does not expand properly',
    27 => 'Invalid instantiation of a scheme constant',
    28 => 'Invalid list of arguments of a functor',
    29 => 'Instantiations of the same scheme functor do not match',
    30 => 'Invalid type of the instantiated functor',
    31 => 'Disagreement of correspondents of a constant',
    32 => 'Too many fillings of a functor',
    33 => 'Too many fillings of a predicate',
    40 => 'Non-unique matching of a locus of the substitute of a predicate variable',
    41 => 'Non-unique matching of a locus of the substitute of a functor variable',
    42 => 'Non-unique matching of a locus of the substitute of a functor variable',
    43 => 'Cannot decompose a conjunction of formal sentences',
    44 => 'Formal predicate in a Fraenkel operator of formal construction',
    45 => 'Wrong order of the declarations of scheme functor or nested functor',
    46 => 'Probably the incorporation of an argument',
    50 => 'Nongeneralizable variable in the skeleton of a reasoning',
    51 => 'Invalid conclusion',
    52 => 'Invalid assumption',
    53 => 'Invalid case',
    54 => 'The cases are not exhausted',
    55 => 'Invalid generalization',
    56 => 'Disagreement of types',
    57 => 'The type of the instatiated term doesn\'t widen properly',
    58 => 'Mixing "case" with "suppose" is not allowed in one "per cases" reasoning',
    59 => 'The theses in each case should be equal formulae',
    60 => 'Something remains to be proved in this case',
    62 => 'Free variables not allowed in an iterative equality',
    63 => 'Unexpected proof',
    64 => 'Invalid exemplification in a diffuse statement',
    65 => '"thesis" is only allowed inside a proof',
 68 => 'Nongeneralizable variable in the skeleton of a reasoning',
 69 => 'Nongeneralizable variable in a definiens',
 70 => 'Something remains to be proved',
 72 => 'Unexpected correctness condition',
 73 => 'Correctness condition missing',
 76 => 'Registration correctness condition mismatch',
 77 => 'Still not implemented',
 78 => 'The type of the argument must widen to the result type',
 79 => 'Types of arguments must be equal',
 80 => 'Cannot be used in a permissive definition',
 81 => 'It is only meaningful for binary predicates',
 82 => 'It is only meaningful for binary functors',
 83 => 'It is only meaningful for unary functors',
 84 => 'The result type is not invariant under swapping the arguments',
 85 => 'The type of the argument must be equal to the result type',
 89 => 'As yet not implemented for redefined functors',
 90 => 'Attributes are not allowed in a prefix',
 91 => 'Homonymic fields in structure declaration',
 92 => 'Type of the field must be equal to the type in prefix',
 93 => 'Missing field of a prefix',
 94 => 'Prefix must be a structure',
 95 => 'Inconsistent cluster',
 96 => 'Only standard functors and selectors can be used in a functorial cluster registration',
 97 => 'Non clusterable attribute',
 98 => 'Cannot mix left and right pattern arguments',
 99 => 'The argument(s) must belong to the left or right pattern',
 100 => 'Unused locus',
 101 => 'Unknown mode',
 102 => 'Unknown predicate',
 103 => 'Unknown functor',
 104 => 'Unknown structure',
 105 => 'Illegal projection',
 106 => 'Unknown attribute',
 107 => 'Invalid list of arguments of redefined constructor',
 108 => 'Invalid list of arguments of redefined constructor',
 109 => 'Invalid order of arguments of redefined constructor',
 110 => 'Only nullary prefixes are allowed',
 111 => 'Non registered attribute cluster',
 112 => 'Unknown predicate',
 113 => 'Unknown functor',
 114 => 'Unknown mode',
 115 => 'Unknown attribute',
 116 => 'Invalid "qua"',
 117 => 'Invalid specification',
 118 => 'Invalid specification',
 119 => 'Illegal cluster',
 120 => 'Disagreement of argument types',
 121 => 'Disagreement of argument types',
 122 => 'Disagreement of argument types',
 123 => 'Disagreement of argument types',
 124 => 'Disagreement of argument types',
 125 => 'Argument of a selector must be a structure',
 126 => 'Unknown selector functor',
 127 => 'Argument must be an elementary type',
 128 => 'Arguments must be elementary types',
 129 => 'Invalid free variables in a Fraenkel operator',
 130 => 'Redefinition of an attribute with predicate pattern is not allowed',
 131 => 'No reserved type for a variable, free in the default type',
 132 => 'Invalid "exactly"',
 133 => 'Cannot cluster attribute with arguments',
 134 => 'Cannot redefine expandable mode',
 135 => 'Inaccessible selector',
 136 => 'Non registered cluster',
 137 => '"SUBSET" missing in the "requirements" directive',
 138 => 'Cannot identify a local constant, free in the default type',
 139 => 'Invalid type of an argument. ',
 140 => 'Unknown variable',
 141 => 'Locus repeated',
 142 => 'Unknown locus',
 143 => 'No implicit qualification',
 144 => 'Unknown label',
 145 => 'Inaccessible label',
 146 => 'Theorem number must be greater than 0',
 147 => 'Unknown theorems file',
 148 => 'Unknown private functor',
 149 => 'Unknown private predicate',
 150 => 'A variable free in default type has explicit qualification',
 151 => 'Unknown mode format',
 152 => 'Unknown functor format',
 153 => 'Unknown predicate format',
 154 => 'Unknown field',
 155 => 'Unknown prefix',
 156 => 'Invalid equality format',
 157 => 'Exactly one term is expected before "is"',
 158 => 'Two different formats for a structure symbol',
 159 => 'Invalid iterative equality',
 160 => 'This variable still cannot be accessed',
 161 => 'Fixed variables cannot be postqualified',
 162 => 'A free variable identified with a new implicit qualification',
 163 => 'Disagreement of reservations of a free variable',
 164 => 'Nothing to link',
 165 => 'Unknown functor format',
 166 => 'Unknown functor format',
 167 => 'Unknown functor format',
 168 => 'Unknown functor format',
 169 => 'Unknown functor format',
 170 => 'Unknown functor format',
 171 => 'Unknown functor format',
 172 => 'Unknown functor format',
 173 => 'Unknown functor format',
 174 => 'Unknown functor format',
 175 => 'Unknown attribute format',
 176 => 'Unknown structure format',
 177 => 'Link assumes a straightforward justification',
 178 => 'Link assumes a straightforward justification',
 179 => 'It is not a locus',
 180 => 'Too many arguments',
 181 => 'Not so many arguments in this definition',
 182 => 'Unknown selector format',
 183 => 'Accessible mode format has empty list of arguments',
 184 => 'Accessible structure format has empty list of arguments',
 185 => 'Unknown structured mode format',
 186 => '"equals" is only allowed for functors',
 189 => 'Left and right pattern must have the same number of arguments',
 190 => 'Inaccessible theorem',
 191 => 'Unknown scheme',
 192 => 'Inaccessible theorem',
 193 => 'Inaccessible scheme',
 194 => 'Wrong number of premises',
 195 => 'Scheme uses constructors which are not in your environment',
 196 => 'Unknown scheme',
 197 => 'Scheme definition repeated',
 198 => 'It is meaningless to define an antonym to a functor or a mode',
 199 => 'Inaccessible definitional theorem',
 200 => 'Too long source line',
 201 => 'Only characters with decimal ASCII codes between 32 and 126 are allowed',
 202 => 'Too large numeral',
 203 => 'Unknown token, maybe an illegal character used in an identifier',
 210 => 'Wrong item in environment declaration',
 211 => 'Unexpected "environ"',
 212 => '"environ" expected',
 213 => '"begin" missing',
 214 => '"end" missing',
 215 => 'No pairing "end" for this word',
 216 => 'Unexpected "end"',
 217 => '";" missing',
 218 => 'Unexpected "(" - parenthesizing attributes is not allowed',
 219 => 'Unexpected "proof"',
 220 => 'Local predicates are not allowed in library items ',
 221 => 'Local functors are not allowed in library items',
 222 => 'Local constants are not allowed in library items  ',
 228 => 'Unexpected "reconsider"',
 229 => '"redefine" repeated',
 230 => 'Only one "per cases" is allowed in a reasoning',
 231 => '"per cases" missing',
 232 => '"case" or "suppose" expected',
 240 => 'Definition blocks must not be nested',
 241 => 'Directives are not allowed in the text proper',
 242 => '"reserve", "struct", "scheme" and "theorem" not allowed in a definition block',
 250 => '"$1",...,"$10" are only allowed inside the definiens of a private constructor',
 251 => '"it" is only allowed inside the definiens of a public functor or mode',
 253 => '"means" or "equals" expected',
 255 => 'It is not allowed for expandable modes',
 271 => 'Redefined mode cannot be expandable',
 272 => 'It\'s meaningless to redefine cluster',
 274 => '"means" not allowed in a definition of an expandable mode',
 300 => 'Identifier expected',
 301 => 'Predicate symbol expected',
 302 => 'Functor symbol expected',
 303 => 'Mode symbol expected',
 304 => 'Structure symbol expected',
 305 => 'Selector symbol expected',
 306 => 'Attribute symbol expected',
 307 => 'Numeral expected',
 308 => 'Identifier or theorem file name expected',
 309 => 'Mode symbol or attribute symbol expected',
 310 => 'Right functor bracket expected',
 311 => 'Paired functor brackets must be of the same kind',
 312 => 'Scheme reference is not allowed in a simple justification',
 313 => '"sch" expected',
 314 => 'Incorrect beginning of a pattern',
 320 => 'Selector or structure symbol expected',
 321 => 'Predicate symbol or "is" expected',
 329 => 'Selector without arguments is only allowed inside a structure pattern',
 330 => 'Unexpected end of an item (perhaps ";" missing)',
 336 => 'Associative notation must not be used for "iff" and "implies"',
 340 => '"holds", "for" or "ex" expected',
 350 => '"that" expected',
 351 => '"cases" expected',
 360 => '"(" expected',
 361 => '"[" expected',
 362 => '"{" expected',
 363 => '"(#" expected',
 364 => '"(" or "[" expected',
 370 => '")" expected',
 371 => '"]" expected',
 372 => '"}" expected',
 373 => '"#)" expected',
  374 => 'Incorrect order of arguments in an attribute definition',
  375 => 'Wrong beginning of a cluster registration',
  376 => 'Incorrect functorial registration - addjectives expected',
  377 => 'Incorrect conditional registration - type expected',
  378 => 'Parenthesizing adjective clusters is not allowed',
  379 => 'Term list is not allowed here',
  380 => '"=" expected',
  381 => '"if" expected',
  382 => '"for" expected',
  383 => '"is" expected',
  384 => '":" expected',
  385 => '"->" expected',
  386 => '"means" or "equals" expected',
  387 => '"st" expected',
  388 => '"as" expected',
  389 => '"proof" expected',
  390 => '"and" expected',
  391 => 'Incorrect beginning of a text item',
  392 => 'Incorrect beginning of a definition item',
  393 => 'Incorrect beginning of a reasoning item',
  394 => 'Statement expected',
  395 => 'Justification expected',
  396 => 'Formula expected',
  397 => 'Term expected',
  398 => 'Type expected',
  399 => 'Functor pattern expected',
  400 => 'Still not implemented',
  450 => 'Too many variables',
  451 => 'Too many predicate formats',
  452 => 'Too many functor formats',
  453 => 'Too many mode formats',
  454 => 'Too large theorem number',
  455 => 'Too many labels in a definition block',
  456 => 'Too many references in an inference',
  458 => 'Too many private predicates',
  459 => 'Too many private functors',
  460 => 'Too many reserved identifiers',
  461 => 'Too many free variables',
  462 => 'Too many modes',
  465 => 'Too many predicates',
  466 => 'Too many functors',
  467 => 'Too many structures',
  468 => 'Too many selectors',
  469 => 'Too many loci',
  470 => 'Too complicated term',
  471 => 'Too many selectors in one structure definition',
  472 => 'Too many references',
  473 => 'Too many justifications',
  474 => 'Too complicated term',
  476 => 'Too many default signature files',
  477 => 'Too many predicate, mode or functor symbols',
  478 => 'Too many labels',
  479 => 'Too many loci in one definition block',
  480 => 'Too many default vocabulary files',
  481 => 'Too many functor symbols in default vocabulary files',
  482 => 'Too many free variable scopes',
  483 => 'Too many variables',
  484 => 'Too many reservations',
  485 => 'Too nested reasoning',
  486 => 'Too many functor formats',
  487 => 'Too many scheme identifiers',
  488 => 'Too many unreserved free variables',
  489 => 'Memory handling in unifier failed',
  490 => 'Too many free variables in reservations',
  491 => 'Too many structure formats',
  492 => 'Too many functor formats',
  493 => 'Too many parameters in one scheme',
  494 => 'Too complicated scheme (too many external variables)',
  495 => 'Too complicated scheme (too many occurrences of a functor variable)',
  496 => 'Too complicated scheme (too many occurrences of a predicate variable)',
  497 => 'Too many functor symbols',
  498 => 'Too many occurrences of arguments of a second order variable',
  499 => 'Too many errors',
  601 => 'Irrelevant label',
  602 => 'Irrelevant reference',
  603 => 'Irrelevant linking',
  604 => 'Irrelevant inference',
  605 => 'Irrelevant linked inference',
  607 => 'Justification can be straightforward',
  608 => 'Linkable statement',
  609 => 'Irrelevant "that"',
  610 => 'Beginning of an inaccessible item',
  611 => 'End of an inaccessible item',
  612 => 'Beginning of inaccessible conditions',
  613 => 'End of inaccessible conditions',
  614 => 'Duplicated label identifier',
  615 => 'Unexpected "@proof"',
  616 => '"be" recommended',
  703 => 'Unnecessary "proof thus thesis; end;"',
  704 => 'Irrelevant signature directive',
  706 => 'Unnecessary item in the "theorems" directive',
  707 => 'Unnecessary item in the "schemes" directive',
  708 => 'Theorem should be replaced by an equal one',
  709 => 'Irrelevant item in the "vocabularies" directive',
  710 => 'Irrelevant item in the "definitions" directive',
  711 => 'Identity functor definition',
  712 => 'Synonym of a functor definition',
  713 => 'Irrelevant redefinition of a functor',
  714 => 'Irrelevant redefinition of a mode',
  715 => 'Irrelevant "reconsider" of a variable',
  716 => 'Irrelevant "reconsider" of a term',
  717 => 'Irrelevant reconsider',
  720 => 'The first two arguments of the iterative equality are equal',
  721 => 'The first argument of the iterative equality is equal to the next one',
  722 => 'The second argument of the iterative equality is equal to the next one',
  724 => 'This argument of the iterative equality is equal to the next one',
  725 => 'This argument of the iterative equality is equal to the previous one',
  730 => 'Redundant reconsidering of variables',
  731 => 'Redundant reconsidering of terms',
  732 => 'Redundant reconsidering of a variable',
  733 => 'Redundant reconsidering of a term',
  734 => 'Redundant considering',
  735 => 'Irrelevant variable reservation',
  736 => 'Unused private functor',
  737 => 'Unused private predicate',
  738 => 'Unused variable introduced by "set"',
  739 => 'The variable introduced by "set" used only once ',
  740 => 'Unused variable introduced by "given"',
  742 => 'Unused variable introduced by "take"',
  743 => 'Unused variable introduced by "consider"',
  746 => 'References can be moved to the next step of this iterative equality',
  800 => 'Library corrupted',
  801 => 'Cannot find vocabulary file',
  802 => 'Cannot find formats file',
  803 => 'Cannot find notations file',
  804 => 'Cannot find signature file',
  805 => 'Cannot find definitions file',
  806 => 'Cannot find theorems file',
  807 => 'Cannot find schemes file',
  808 => 'Cannot find constructors file',
  809 => 'Cannot find registrations file',
  810 => 'Directive name repeated',
  811 => 'Invalid priority of a functor symbol on a vocabulary file',
  812 => 'An empty line on a vocabulary file',
  813 => 'Invalid qualifier on a vocabulary file',
  814 => 'Invalid character or space in a symbol',
  815 => 'A vocabulary symbol repeated',
  816 => 'Invalid priority',
  817 => 'An empty symbol',
  821 => 'A scheme identifier repeated',
  825 => 'Cannot find constructors name on constructor list',
  830 => 'Nothing imported from notations',
  831 => 'Nothing imported from registrations',
  832 => 'Nothing imported from definitions',
  833 => 'Nothing imported from theorems',
  834 => 'Nothing imported from schemes',
  855 => 'Cannot find requirements file',
  856 => 'Inaccessible requirements directive',
  891 => 'MML identifier should be written in capitals',
  892 => 'MML identifier should be at most eight characters long',
  900 => 'Too complex skeleton',
  911 => 'Too long term without parentheses',
  912 => 'Too long right nesting of a term',
  913 => 'Too many labels (simultaneously accessible)',
  914 => 'Too many references in an inference',
  915 => 'Too many ranges of free variables',
  916 => 'Too many reservations',
  917 => 'Too many free variables in reservations',
  918 => 'Too many variables (simultaneously accessible)',
  919 => 'Too many reserved identifiers',
  920 => 'Too many private functors',
  921 => 'Too many private predicates',
  923 => 'Too many different clusters',
  924 => 'Common number of loci exceeded',
  925 => 'Too many predicate patterns',
  926 => 'Too many functors',
  927 => 'Too many functor patterns',
  928 => 'Too many modes',
  929 => 'Too many mode patterns',
  930 => 'Too many attributes',
  931 => 'Too many attribute patterns',
  933 => 'Too many structures',
  935 => 'Too many selectors',
  936 => 'Too many registered clusters',
  937 => 'Too many arguments',
  938 => 'Too many terms',
  950 => 'Too many schemes',
  951 => 'Too many imported files',
  1001 => 'Invalid function number',
  1002 => 'File not found',
  1003 => 'Path not found',
  1004 => 'Too many open files',
  1005 => 'File access denied',
  1006 => 'Invalid file handle',
  1012 => 'Invalid file access code',
  1015 => 'Invalid drive number',
  1016 => 'Cannot remove current directory',
  1017 => 'Cannot rename across drives',
  1018 => 'No more files',
  1100 => 'Disk read error',
  1101 => 'Disk write error',
  1102 => 'File not assigned',
  1103 => 'File not open',
  1104 => 'File not open for input',
  1105 => 'File not open for output',
  1106 => 'Invalid numeric format',
  1150 => 'Disk is write-protected',
  1151 => 'Bad drive request struct length',
  1152 => 'Drive not ready',
  1154 => 'CRC error in data',
  1156 => 'Disk seek error',
  1157 => 'Unknown media type',
  1158 => 'Sector Not Found',
  1159 => 'Printer out of paper',
  1160 => 'Device write fault',
  1161 => 'Device read fault',
  1162 => 'Hardware failure',
  1200 => 'Division by zero',
  1201 => 'Range check error',
  1202 => 'Stack overflow error',
  1203 => 'Heap overflow error',
  1204 => 'Invalid pointer operation',
  1205 => 'Floating point overflow',
  1206 => 'Floating point underflow',
  1207 => 'Invalid floating point operation',
  1208 => 'Overlay manager not installed',
  1209 => 'Overlay file read error',
  1210 => 'Object not initialized',
  1211 => 'Call to abstract method',
  1212 => 'Stream registration error',
  1213 => 'Collection index out of range',
  1214 => 'Collection overflow error',
  1215 => 'Arithmetic overflow error',
  1216 => 'General Protection fault',
  1217 => 'Segmentation fault',
  1255 => 'Ctrl Break',
  1994 => 'I/O stream error: Put of unregistered object type',
  1995 => 'I/O stream error: Get of unregistered object type',
  1996 => 'I/O stream error: Cannot expand stream',
  1997 => 'I/O stream error: Read beyond end of stream',
  1998 => 'I/O stream error: Cannot initialize stream',
  1999 => 'I/O stream error: Access error');

sub lookup_error_code {
  my $code = shift;
  my $message = $mizar_errors{$code};
  if (defined $message) {
    return $message;
  } else {
    return "(unknown error code $code)";
  }
}

1;
