#!/usr/bin/perl -w

# First sanity check: make sure that MIZFILES is set.  We can't do
# anything it is not set.  Let's not check whether it is a sensible
# value, just that it has some value.
my $mizfiles = $ENV{'MIZFILES'};
unless (defined $mizfiles) {
  die 'Error: The MIZFILES environment variable is unset; nothing more can be done';
}

use Getopt::Euclid; # load this first to set up our command-line parser

use Cwd qw / getcwd /;
use File::Temp qw / tempdir /;
use File::Spec::Functions qw / catfile /;
use File::Copy qw / copy move /;
use File::Path qw / remove_tree /;
use XML::LibXML;

######################################################################
### Process the command line
###
###
### We are using Getopt::Euclid; see the documentation section at the
### end of this file to see what command-line options are available.
######################################################################

### --verbose

## Process --verbose first, because if it is set, then we want to
## print stuff out as we process the rest of the command-line
## arguments.

my $be_verbose = 0;
if (defined $ARGV{'--verbose'}) {
  $be_verbose = 1;
}

### --article-source-dir

# First, extract a value
my $article_source_dir = $ARGV{'--article-source-dir'};
if (defined $article_source_dir) {
  if ($be_verbose) {
    print "Setting the article source directory to '$article_source_dir', as requested\n";
  }
} else {
  $article_source_dir = "$mizfiles/mml";
  if ($be_verbose) {
    print "Setting the article source directory to '$article_source_dir' (which is the default)\n";
  }
}

# Now ensure that this value for is sensible, which in this case
# means: it exists, it's directory, and it's readable.
unless (-e $article_source_dir) {
  die "Error: The given article source directory\n\n  $article_source_dir\n\ndoes not exist!";
}
unless (-d $article_source_dir) {
  die "Error: The given article source directory\n\n$article_source_dir\n\nis not actually a directory!";
}
unless (-r $article_source_dir) {
  die "Error: The given article source directory\n\n$article_source_dir\n\nis not readable!";
}

### --result-dir

# First, extract a value.  The default is to use the current directory.
my $result_dir = $ARGV{'--result-dir'};
unless (defined $result_dir) {
  $result_dir = getcwd ();
}

# Ensure that the value is sensible, which in this case means: it
# exists, it's a directory, and it's writable
unless (-e $result_dir) {
  die "Error: The given result directory\n\n  $result_dir\n\ndoes not exist!";
}
unless (-d $result_dir) {
  die "Error: The given result directory\n\n$result_dir\n\nis not actually a directory!";
}
unless (-w $result_dir) {
  die "Error: The given result directory\n\n$result_dir\n\nis not writable!";
}

if ($be_verbose) {
  print "Setting the result directory to '$result_dir'\n";
}

### --emacs-lisp-dir

# First, extract or assign a value.  As was the case for the
# --result-dir option, a default value has already been specified
# using Getopt::Euclid, so there's no need to compute a default.
my $elisp_dir = $ARGV{'--emacs-lisp-dir'};
unless (defined $elisp_dir) { # weird: typo on my part or bug in Getopt::Euclid
  die 'Error: No value for the --emacs-lisp-dir option is present in the %ARGV table!';
}

if ($be_verbose) {
  print "Setting elisp directory to $elisp_dir\n";
}

# Ensure that the value is sensible, which in this case means: it
# exists, it's a directory, it's readable, and it contains all the
# needed helper elisp code
unless (-e $elisp_dir) {
  die "Error: The given emacs lisp directory\n\n  $elisp_dir\n\ndoes not exist!";
}
unless (-d $elisp_dir) {
  die "Error: The given emacs lisp directory\n\n$elisp_dir\n\nis not actually a directory!";
}
unless (-r $elisp_dir) {
  die "Error: The given emacs lisp directory\n\n$elisp_dir\n\nis not readable!";
}
my @elisp_files = ('reservations.elc');
foreach my $elisp_file (@elisp_files) {
  my $elisp_file_path = catfile ($elisp_dir, $elisp_file);
  unless (-e $elisp_file_path) {
    die "Error: The required emacs lisp file\n\n  $elisp_file\n\ncannot be found under the emacs lisp directory\n\n$elisp_dir";
  }
  unless (-r $elisp_file_path) {
    die "Error: The required emacs lisp file\n\n  $elisp_file\n\nunder the emacs lisp directory\n\n$elisp_dir\n\nis not readable!";
  }
}
my $reservations_elc_path = catfile ($elisp_dir, 'reservations.elc');
unless (-e $reservations_elc_path) {
  die "Error: reservations.elc does not exist under $elisp_dir";
}
unless (-r $reservations_elc_path) {
  die "Error: reservations.elc under $elisp_dir is not readable";
}

### --with-stylesheets-in

# First, extract or assign a value.
my $stylesheet_dir = $ARGV{'--with-stylesheets-in'};
if ($be_verbose) {
  print "Looking for stylesheets in directory '$stylesheet_dir'\n";
}

# Now ensure that the value is sensible, which in this case means that
# the path refers to an existing, readable directory and that that
# directory contains all the relevant stylesheets (and that these are
# all readable)
unless (-e $stylesheet_dir) {
  die "Error: the stylesheet directory '$stylesheet_dir' does not exist!";
}
unless (-d $stylesheet_dir) {
  die "Error: the stylesheet directory '$stylesheet_dir' is not actually a directory!";
}
unless (-r $stylesheet_dir) {
  die "Error: the stylesheet directory '$stylesheet_dir' is not readable!";
}

# We've established that the stylesheet directory is reachable.  Now
# check that all the required stylesheets are reachable in that
# directory.
my @stylesheets = ('addabsrefs');
foreach my $stylesheet (@stylesheets) {
  my $stylesheet_xsl = "$stylesheet.xsl";
  my $stylesheet_path = catfile ($stylesheet_dir, $stylesheet_xsl);
  unless (-e $stylesheet_path) {
    die "The required stylesheet $stylesheet_xsl does not exist in $stylesheet_dir";
  }
  unless (-r $stylesheet_path) {
    die "The required stylesheet $stylesheet_xsl, under $stylesheet_dir, is not readable";
  }
}

### ARTICLE

# First, extract a value of the single required ARTICLE
# argument.
my $article_name = $ARGV{'<ARTICLE>'};
unless (defined $article_name) { # weird: my typo or bug in Getopt::Euclid
  die 'Error: The mandatory ARTICLE argument was somehow omitted!';
}

# Strip the final ".miz", if there is one
my $article_name_len = length $article_name;
if ($article_name =~ /\.miz$/) {
  $article_name = substr $article_name, 0, $article_name_len - 4;
}

if ($be_verbose) {
  print "Working with article '$article_name'\n";
}

# Some common extensions we'll be using, and their paths
my $article_miz = $article_name . '.miz';
my $article_err = $article_name . '.err'; # for error checking with the mizar tools
my $article_tmp = $article_name . '.$-$';
my $article_miz_path = catfile ($article_source_dir, $article_miz);
my $article_err_path = catfile ($article_source_dir, $article_err);
my $article_tmp_path = catfile ($article_source_dir, $article_tmp);

# More sanity checks: the mizar file exists and is readable
unless (-e $article_miz_path) {
  die "Error: No file named\n\n  $article_miz\n\nunder the source directory\n\n  $article_source_dir";
}
unless (-r $article_miz_path) {
  die "Error: The file\n\n  $article_miz\n\under the source directory\n\n  $article_source_dir\n\nis not readable";
}

### --no-cleanup
my $cleanup_afterward = 1;
if (defined $ARGV{'--no-cleanup'}) {
  $cleanup_afterward = 0;
}

######################################################################
### End command-line processing.
###
### Now we can start doing something.
######################################################################

######################################################################
### Prepare result directories:
###
### 1. The work directory, where sed, JA1, emacs, etc., will be run.
###
### 2. The local article database.
######################################################################

### 1. Prepare the work directory.

# First, create it.
my $workdir = tempdir (CLEANUP => $cleanup_afterward)
  or die 'Error: Unable to create a working directory!';

if ($be_verbose) {
  print "Setting the work directory to $workdir\n";
}

# Now copy the specified mizar article to the work directory
my $article_in_workdir = catfile ($workdir, $article_miz);
copy ($article_miz_path, $article_in_workdir)
  or die "Error: Unable to copy article ($article_miz) to work directory ($article_in_workdir):\n\n$!";

### 2. Prepare the result directory

## But first check whether it already exists.  If it does, stop; we
## don't want to potentially overwrite anything.
my $local_db = catfile ($result_dir, $article_name);
if (-x $local_db) {
  die "Error: there is already a directory called '$article_name' in the result directory ($result_dir); refusing to overwrite its contents";
}

if ($be_verbose) {
  print "Article fragments will be stored in '$local_db'\n";
}

mkdir $local_db
  or die "Error: Unable to make the local database directory: $!";
my @local_db_subdirs = ('dict', 'prel', 'text');
my $article_text_dir = catfile ($local_db, 'text');

foreach my $local_db_subdir (@local_db_subdirs) {
  my $local_db_path = catfile ($local_db, $local_db_subdir);
  mkdir $local_db_path
    or die "Error: Unable to make local database subdirectory $local_db_subdir: $!";
}

######################################################################
### Prepare article for itemization:
###
### 1. Run the accomodator (needed for JA1)
###
### 2. Run JA1 and edtfile
###
### 3. Verify (and generate article XML)
###
### 4. Generate the absolute reference version of the generated XML
######################################################################

### 1. Run the accomodator
chdir $workdir;
system ("accom -q -s -l $article_miz > /dev/null 2> /dev/null");
unless ($? == 0) {
  die "Error: Something went wrong when calling the accomodator on $article_name: the error was\n\n$!";
}
if (-s $article_err) {
  die "Error: although the accomodator returned successfully, it nonetheless generated a non-empty error file";
}


### 2. Run JA1 and edtfile
system ("JA1 -q -s -l $article_miz > /dev/null 2> /dev/null");
unless ($? == 0) {
  die "Error: Something went wrong when calling JA1 on $article_name: the error was\n\n$!";
}
if (-s $article_err) {
  die "Error: although the JA1 tool returned successfully, it nonetheless generated a non-empty error file";
}
system ("edtfile $article_name > /dev/null 2> /dev/null");
unless ($? == 0) {
  die ("Error: Something went wrong during the call to edtfile on $article_name:\n\n  $!");
}
if (-s $article_err) {
  die "Error: although the edtfile tool returned successfully, it nonetheless generated a non-empty error file";
}
unless (-e $article_tmp) {
  die "Error: the edtfile tool did not generate the expected file '$article_tmp'";
}
unless (-r $article_tmp) {
  die "Error: the file generated by the edtfile tool, '$article_tmp', is not readable";
}
move ($article_tmp, $article_miz) == 1
  or die "Error: unable to rename the temporary file\n\n  $article_tmp\n\nto\n\n  $article_miz\n\nin the work directory\n\n  $workdir .\n\nThe error was\n\n  $!";

### 3. Verify (and generate article XML)
system ("verifier -s -q -l $article_miz > /dev/null 2> /dev/null");
unless ($? == 0) {
  die "Error: something went wrong verifying $article_miz: the error was\n\n$!";
}
unless (-z $article_err) {
  die "Error: although the verifier returned successfully, it nonetheless generated a non-empty error file";
}

### 4. Generate the absolute reference version of the generated XML
my $absrefs_stylesheet = catfile ($stylesheet_dir, 'addabsrefs.xsl');
my $article_xml = $article_name . '.xml';
my $article_xml_absrefs = $article_name . '.xml1';
my $article_idx = $article_name . '.idx';
unless (-e $absrefs_stylesheet) {
  die "The absolute reference stylesheet could not be found under $stylesheet_dir!";
}
unless (-r $absrefs_stylesheet) {
  die "The absolute reference styesheet under $stylesheet_dir is not readable.";
}
chdir $workdir;
system ("xsltproc $absrefs_stylesheet $article_xml 2> /dev/null > $article_xml_absrefs");
unless ($? == 0) {
  die ("Something went wrong when creating the absolute reference XML: the error was\n\n$!");
}

######################################################################
### We're done setting up the work directory; now we can use the
### intermediate files we just generated to split up the given article
### into its constituent items.
######################################################################

sub fetch_directive {
  my $directive = shift;

  my $article_evl = $article_name . '.evl';

  chdir $workdir;
  system ("envget -l $article_miz > /dev/null 2> /dev/null");

  # This is the way things should be, but envget doesn't behave as expected!

  # unless ($? == 0) {
  #   die ("Something went wrong when calling envget on $article_base.\nThe error was\n\n  $!");
  # }

  # But let's check for an error file:
  unless (-z $article_err) {
    die "Error: envget generated a non-empty error file while fetching the value of the directive $directive";
  }

  # cheap approach: take advantage of the fact the the Directives in the
  # EVL file all begin at the beginning of the line
  my $evl_directive = "sed -n -e '/^<Directive name=\"$directive\"/,/^<\\/Directive/p' $article_evl";
  # another cheap trick like the one above
  my $select_identifiers = 'grep "^<Ident name="';

  # now delete all the padding
  my $name_equals_field = 'cut -f 2 -d \' \'';
  my $name_right_hand_side = 'cut -f 2 -d \'=\'';
  my $de_double_quote = 'sed -e \'s/"//g\'';

  my $big_pipe = "$evl_directive | $select_identifiers | $name_equals_field | $name_right_hand_side | $de_double_quote";

  my @directive_items = `$big_pipe`;
  chomp (@directive_items);
  @directive_items = grep (!/^HIDDEN$/, @directive_items);
  return @directive_items;
}

# article environment
my @vocabularies = fetch_directive ('Vocabularies');
my @notations = fetch_directive ('Notations');
my @constructors = fetch_directive ('Constructors');
my @registrations = fetch_directive ('Registrations');
my @requirements = fetch_directive ('Requirements');
my @definitions = fetch_directive ('Definitions');
my @theorems = fetch_directive ('Theorems');
my @schemes = fetch_directive ('Schemes');

# DEBUG
warn "The vocabularies environment is @vocabularies\n";

my @mml_lar = ();

sub read_mml_lar {
  open (MML_LAR, q{<}, '/sw/share/mizar/mml.lar')
    or die ("mml.lar cannot be opened: $!");
  my $line;
  while (defined ($line = <MML_LAR>)) {
    chomp $line;
    push (@mml_lar, $line);
  }
  close (MML_LAR)
    or die ("Can't close read-only filehandle for mml.lar: $!");
  return;
}

read_mml_lar ();

sub export_item {
  my $number = shift;
  my $begin_line = shift;
  my $text = shift;

  my $item_path = catfile ($article_text_dir, "ITEM$number.miz");
  open (ITEM_MIZ, q{>}, $item_path)
    or die ("Unable to open an output filehandle at $item_path:\n\n  $!");
  print ITEM_MIZ ("environ\n");

  # vocabularies are easy
  my @this_item_vocabularies = @vocabularies;
  unless (scalar (@this_item_vocabularies) == 0) {
    print ITEM_MIZ ("vocabularies " . join (', ', @this_item_vocabularies) . ";");
    print ITEM_MIZ ("\n");
  }

  # notations
  my @this_item_notations = @notations;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_notations, "ITEM$i");
  }
  unless ($number == 1) {
    print ITEM_MIZ ("notations " . join (', ', @this_item_notations) . ";");
    print ITEM_MIZ ("\n");
  }

  # constructors
  my @this_item_constructors = @constructors;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_constructors, "ITEM$i");
  }
  unless ($number == 1) {
    print ITEM_MIZ ("constructors " . join (', ', @this_item_constructors) . ";");
    print ITEM_MIZ ("\n");
  }

  # registrations
  my @this_item_registrations = @registrations;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_registrations, "ITEM$i");
  }
  unless ($number == 1) {
    print ITEM_MIZ ("registrations " . join (', ', @this_item_registrations) . ";");
    print ITEM_MIZ ("\n");
  }

  # requirements is "easy"
  my @this_item_requirements = @requirements;
  unless (scalar (@this_item_requirements) == 0) {
    print ITEM_MIZ ("requirements " . join (', ', @this_item_requirements) . ";");
    print ITEM_MIZ ("\n");
  }

  # handle the definitions directive just like the constructors directive
  my @this_item_definitions = @definitions;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_definitions, "ITEM$i");
  }
  unless ($number == 1) {
    print ITEM_MIZ ("definitions " . join (', ', @this_item_definitions) . ";");
    print ITEM_MIZ ("\n");
  }

  # theorems
  my @this_item_theorems = @theorems;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_theorems, "ITEM$i");
  }
  unless ($number == 1) {
    print ITEM_MIZ ("theorems " . join (', ', @this_item_theorems) . ";");
    print ITEM_MIZ ("\n");
  }

  # schemes
  my @this_item_schemes = @schemes;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_schemes, "ITEM$i");
  }
  unless ($number == 1) {
    print ITEM_MIZ ("schemes " . join (', ', @this_item_schemes) . ";");
    print ITEM_MIZ ("\n");
  }

  print ITEM_MIZ ("\n");
  print ITEM_MIZ ("begin\n");

  # reservations
  my @reservations = @{reservations_before_line ($begin_line)};
  foreach my $reservation (@reservations) {
    print ITEM_MIZ ("reserve $reservation\n");
  }

  # the item proper
  print ITEM_MIZ ("$text;");

  print ITEM_MIZ ("\n");

  close (ITEM_MIZ) or die ("Unable to close the filehandle for the path $item_path");
}

# the XPath expression for proofs that are not inside other proof
my $top_proof_xpath = '//Proof[not((name(..)="Proof") 
          or (name(..)="Now") or (name(..)="Hereby")
          or (name(..)="CaseBlock") or (name(..)="SupposeBlock"))]';

sub read_miz_file {
  # read the whole mizar file as a sequence of strings
  my @mizfile_lines = ();
  open (MIZFILE, q{<}, $article_miz)
    or die ("Unable to open file $article_miz for reading.");
  my $miz_line;
  while (defined ($miz_line = <MIZFILE>)) {
    chomp $miz_line;
    push (@mizfile_lines, $miz_line);
  }
  close (MIZFILE)
    or die ("Unable to close the input filehandle for $article_miz!");
  return (\@mizfile_lines);
}

sub miz_xml {
  my $parser = XML::LibXML->new();
  return ($parser->parse_file($article_xml_absrefs));
}

sub miz_idx {
  my $parser = XML::LibXML->new();
  return ($parser->parse_file($article_idx));
}

my %reservation_table = ();

sub nulls_to_newlines {
  my $str = shift;
  $str =~ s/\0/\n/g;
  return ($str);
}

sub init_reservation_table {
  my @output = `emacs23 --quick --batch --load $reservations_elc_path --visit $article_miz --funcall find-reservations`;
  unless ($? == 0) {
    die ("Weird: emacs didn't exit cleanly: $!");
  }
  my $num_lines = scalar (@output);
  for (my $i = 0; $i < $num_lines; $i = $i + 2) {
    my $line_number = $output[$i];
    my $reservation_block_nulled = $output[$i+1];
    chomp ($line_number);
    chomp ($reservation_block_nulled);
    $reservation_table{$line_number}
      = nulls_to_newlines ($reservation_block_nulled);
  }
}

sub reservations_from_xml {
  my $doc = miz_xml ();
  my @reservations = $doc->findnodes ('/Reservation');
  return (\@reservations);
}

my %vid_table = ();

sub init_vid_table {
  my $doc = miz_idx ();
  my @symbols = $doc->findnodes ('//Symbol');
  foreach my $symbol (@symbols) {
    my $vid = $symbol->findvalue ('@nr');
    my $name = $symbol->findvalue ('@name');
    # DEBUG
    warn ("setting vid $vid to label $name...");
    $vid_table{$vid} = $name;
  }
}

init_vid_table ();

# sub prepare_work_dirs {
#   my $theorems_dir = $article_work_dir . '/' . 'theorems';
#   my $schemes_dir = $article_work_dir . '/' . 'schemes';
#   my $definitions_dir = $article_work_dir . '/' . 'definitions';
#   mkdir ($theorems_dir);
#   mkdir ($definitions_dir);
#   return;
# }

# sub load_environment {
#   my @output = `emacs23 --quick --batch --load reservations.elc --visit $article_miz --funcall article-environment`;
#   unless ($? == 0) {
#     die ("Weird: emacs didn't exit cleanly: $!");
#   }
#   # can't we just turn this list of strings into a single string,
#   # using a builtin command?  this looks so primitive
#   my $environment = '';		# empty string
#   foreach my $line (@output) {
#     chomp ($line);
#     $environment .= "$line\n";
#   }
#   return ($environment);
# }

sub print_reservation_table {
  # DEBUG
  warn "Here is the reservation table:";
  foreach my $key (keys (%reservation_table)) {
    print "$key:\n";
    print ($reservation_table{$key});
    print ("\n");
  }
  return;
}

sub reservations_before_line {
  my $line = shift;
  my @reservations = ();
  foreach my $key (sort {$a <=> $b} keys %reservation_table) {
    if ($key < $line) {
      push (@reservations, $reservation_table{$key});
    }
  }
  return (\@reservations);
}

sub scheme_before_position {
  my $line = shift;
  my $col = shift;
  my $scheme = '';		# empty string
  # DEBUG
  my @output = `emacs23 --quick --batch --load $reservations_elc_path --visit $article_miz --eval '(scheme-before-position $line $col)'`;
  unless ($? == 0) {
    die ("Weird: emacs died: $!");
  }
  chomp (@output);
  foreach my $i (0 .. scalar (@output) - 1) {
    my $out_line = $output[$i];
    $scheme .= $out_line;
    if ($i == scalar (@output) - 1) {
      $scheme .= " ";
    } else {
      $scheme .= "\n";
    }
  }
  return ($scheme);
}

sub theorem_before_position {
  my $line = shift;
  my $col = shift;
  my $theorem = '';		# empty string
  # DEBUG
  my @output = `emacs23 --quick --batch --load $reservations_elc_path --visit $article_miz --eval '(theorem-before-position $line $col)'`;
  unless ($? == 0) {
    die ("Weird: emacs died: $!");
  }
  foreach $out_line (@output) {
    chomp ($out_line);
    $theorem .= "$out_line\n";
  }
  return ($theorem);
}

sub definition_before_position {
  my $line = shift;
  my $col = shift;
  my $definition = '';		# empty string
  # DEBUG
  my @output = `emacs23 --quick --batch --load $reservations_elc_path --visit $article_miz --eval '(definition-before-position $line $col)'`;
  unless ($? == 0) {
    die ("Weird: emacs died: $!");
  }
  foreach $out_line (@output) {
    chomp ($out_line);
    $definition .= "$out_line\n";
  }
  return ($definition);
}

sub extract_article_region_replacing_schemes_and_definitions_and_theorems {
  my $item_kind = shift;
  my $label = shift;
  my $bl = shift;
  my $bc = shift;
  my $el = shift;
  my $ec = shift;
  my $schemes_ref = shift;
  my $definitions_ref = shift;
  my $theorems_ref = shift;
  my @schemes = @{$schemes_ref};
  my @definitions = @{$definitions_ref};
  my @theorems = @{$theorems_ref};

  my $emacs_command;
  if (scalar (@schemes) == 0 && scalar (@definitions) == 0 && scalar (@theorems) == 0) {
    $emacs_command = "emacs23 --quick --batch --load $reservations_elc_path --visit $article_miz --eval \"(extract-region-replacing-schemes-and-definitions-and-theorems '$item_kind \\\"$label\\\" $bl $bc $el $ec)\"";
  } else {
    # build the last argument to the EXTRACT-REGION-REPLACING-SCHEMES function
    my $instructions = '';
    foreach my $scheme_triple_ref (@schemes) {
      my @scheme_triple = @{$scheme_triple_ref};
      my $scheme_line = $scheme_triple[0];
      my $scheme_col = $scheme_triple[1];
      my $scheme_abs_num = $scheme_triple[2];
      $instructions .= "'(scheme $scheme_line $scheme_col $scheme_abs_num)";
      $instructions .= " ";
    }
    foreach my $definition_info_ref (@definitions) {
      my @definition_info = @{$definition_info_ref};
      my $def_line = $definition_info[0];
      my $def_col = $definition_info[1];
      my $def_abs_num = $definition_info[2];
      my $def_def_num = $definition_info[3];
      $instructions .= "'(definition $def_line $def_col $def_abs_num $def_def_num)";
      $instructions .= " ";
    }
    foreach my $theorem_triple_ref (@theorems) {
      my @theorem_triple = @{$theorem_triple_ref};
      my $theorem_line = $theorem_triple[0];
      my $theorem_col = $theorem_triple[1];
      my $theorem_abs_num = $theorem_triple[2];
      $instructions .= "'(theorem $theorem_line $theorem_col $theorem_abs_num)";
      $instructions .= " ";
    }

    $emacs_command = "emacs23 --quick --batch --load $reservations_elc_path --visit $article_miz --eval \"(extract-region-replacing-schemes-and-definitions-and-theorems '$item_kind \\\"$label\\\" $bl $bc $el $ec $instructions)\"";
  }

  my $region = ''; # empty string

  # DEBUG
  warn ("emacs command:\n\n  $emacs_command");
  my @output = `$emacs_command`;
  unless ($? == 0) {
    die ("Weird: emacs died: $!");
  }
  foreach $out_line (@output) {
    chomp ($out_line);
    $region .= "$out_line\n";
  }
  return ($region);
}

# prepare_work_dirs ();
init_reservation_table ();
# DEBUG
print_reservation_table ();
# load_environment ();
my $miz_lines_ref = read_miz_file ();
my @mizfile_lines = @{$miz_lines_ref};

my %vid_to_theorem_num = ();
my %theorem_num_to_vid = ();
my %vid_to_diffuse_lemma_num = ();
my %diffuse_lemmas_to_vid = ();
my %vid_to_scheme_num = ();
my %scheme_num_to_vid = ();

sub article_local_references_from_nodes {
  my @nodes = @{shift ()};
  my %local_refs = ();
  foreach my $node (@nodes) {
    my @refs = $node->findnodes ('.//Ref');
    foreach my $ref (@refs) {
      unless ($ref->exists ('@articlenr')) { # this is a local ref
	my $ref_item_vid = $ref->findvalue ('@vid');
	my $ref_item_nr = $ref->findvalue ('@nr');
	my $earlier_nr = $vid_to_theorem_num{$ref_item_vid};
	if (defined ($earlier_nr)) {
	  $local_refs{$ref_item_nr} = 0;
	}
      }
    }
  }
  return (keys (%local_refs));
}

sub line_and_column {
  my $node = shift;

  my ($line,$col);

  if ($node->exists ('@line')) {
    $line = $node->findvalue ('@line');
  } else {
    die ("Node lacks a line attribute");
  }

  if ($node->exists ('@col')) {
    $col = $node->findvalue ('@col');
  } else {
    die ("Node lacks a col attribute");
  }

  return ($line,$col);
}



sub extract_toplevel_unexported_theorem_with_label {
  my $end_line = shift;
  my $end_col = shift;
  my $label = shift;
  my @output = `emacs23 --quick --batch --load $reservations_elc_path --visit $article_miz --eval '(toplevel-unexported-theorem-before-position-with-label $end_line $end_col \"$label\")'`;
  unless ($? == 0) {
    die ("Weird: emacs died extracting the unexported theorem with label $label before position ($end_line,$end_col): the error was: $!");
  }
  chomp (@output);
  my $result = '';
  foreach my $line (@output) {
    $result .= $line;
  }
  return $result;
}

sub pretext_from_item_type_and_beginning {
  my $item_type = shift;
  my $begin_line = shift;
  my $begin_col = shift;
  my $item_node = shift;
  my $pretext;
  if ($item_type eq 'JustifiedTheorem') {
    $pretext = theorem_before_position ($begin_line, $begin_col);
  } elsif ($item_type eq 'Proposition') {
    my $vid = $item_node->findvalue ('@vid');
    # DEBUG
    warn ("unexported toplevel theorem with vid $vid...");
    my $prop_label = $vid_table{$vid};
    # DEBUG
    warn ("unexported toplevel theorem has label $prop_label...");
    my $theorem = extract_toplevel_unexported_theorem_with_label ($begin_line, $begin_col, $prop_label);
    $pretext = "theorem $theorem\n";
  } elsif ($item_type eq 'SchemeBlock') {
    $pretext = scheme_before_position ($begin_line, $begin_col);
    # DEBUG
    warn ("we're dealing with a scheme, and the pretext is $pretext\n");
  } elsif ($item_type eq 'NotationBlock') {
    $pretext = "notation\n";
  } elsif ($item_type eq 'DefinitionBlock') {
    $pretext = "definition\n";
  } elsif ($item_type eq 'RegistrationBlock') {
    $pretext = "registration\n";
  } else {
    $pretext = '';
  }
  return ($pretext);
}

my %scheme_num_to_abs_num = ();
my %definition_nr_to_absnum = ();
my %definition_vid_to_absnum = ();
my %definition_vid_to_thmnum = ();
my %theorem_nr_to_absnum = ();
my %theorem_vid_to_absnum = ();

sub position_of_theorem_keyword_before_pos {
  my $line = shift;
  my $col = shift;
  my @output = `emacs23 --quick --batch --load $reservations_elc_path --visit $article_miz --funcall (position-of-theorem-keyword-before-position)`;
}

sub is_exported_deftheorem {
  my $deftheorem_node = shift;
  my $node_name = $deftheorem_node->nodeName ();
  unless ($node_name eq 'DefTheorem') {
    die ('This is not even a DefTheorem node!');
  }
  my ($prop_node) = $deftheorem_node->findnodes ('Proposition');
  unless (defined $prop_node) {
    die "Weird: a DefTheorem node lacks a Proposition child element";
  }
  return $prop_node->exists ('@vid');
}

sub itemize {
  my $doc = miz_xml ();

  my @final_deftheorem_nodes = $doc->findnodes ('//Article/DefTheorem[name(following-sibling::*) != "DefTheorem"]');
  # DEBUG
  warn ("There are " . scalar (@final_deftheorem_nodes) . " final DefTheorem nodes to consider");
  foreach my $i (1 .. scalar (@final_deftheorem_nodes)) {
    my $final_deftheorem_node = $final_deftheorem_nodes[$i-1];


    # find the first DefTheorem after this definitionblock
    # DefinitionBlock that give rise to exported theorems
    my $current_node = $final_deftheorem_node;
    while ($current_node->nodeName () eq 'DefTheorem') {
      $current_node = $current_node->previousNonBlankSibling ();
    }

    # now that we know how many exported DefTheorems this
    # DefinitionBlock gave rise to, we need to harvest the vid's of
    # the Proposition child elements of such DefTheorems; these are
    # the vid's that we'll need later.

    # reuse $current_node from the previous loop -- it is the last
    # DefTheorem node generated by the DefinitionBlock.  We need to go
    # *forward* now to ensure that items getting the same label (i.e.,
    # the same vid) are mapped to their *last* (re)definition.
    $current_node = $current_node->nextNonBlankSibling ();
    my $num_exported_theorems = 1;
    while ((defined $current_node) && $current_node->nodeName () eq 'DefTheorem') {
      if (is_exported_deftheorem ($current_node)) {
	my ($prop_node) = $current_node->findnodes ('Proposition');
	my $vid = $prop_node->findvalue ('@vid');
	# DEBUG
	$definition_vid_to_thmnum{$vid} = $num_exported_theorems;
	# DEBUG
	warn ("We just assigned vid $vid to exported thereom number $num_exported_theorems of this definition block (we don't know yet what the absolute number of this definitionblock is)");
      }
      $current_node = $current_node->nextNonBlankSibling ();
      $num_exported_theorems++;
    }

    # DEBUG
    warn ("final deftheorem number $i generated $num_exported_theorems exported theorems");
  }

  @tpnodes = $doc->findnodes ('//JustifiedTheorem | //Proposition[(name(..)="Article")] | //DefinitionBlock | //SchemeBlock | //RegistrationBlock | //NotationBlock');
  my $scheme_num = 0;
  # DEBUG
  warn ("we have to consider " . scalar (@tpnodes) . " nodes");
  foreach my $i (1 .. scalar (@tpnodes)) {
    my $node = $tpnodes[$i-1];
    my $node_name = $node->nodeName;

    # register a scheme, if necessary
    if ($node_name eq 'SchemeBlock') {
      $scheme_num++;
      $scheme_num_to_abs_num{$scheme_num} = $i;
      # DEBUG
      warn ("declaring that scheme $scheme_num is absolute item number $i...");
    }

    # register definitions, making sure to count the ones that
    # generate DefTheorems
    if ($node_name eq 'DefinitionBlock') {
      my @local_definition_nodes = $node->findnodes ('.//Definition');
      # DEBUG
      warn ("This node has " . scalar (@local_definition_nodes) . " Definition child elements");
      foreach my $local_definition_node (@local_definition_nodes) {
	# my $nr = $local_definition_node->findvalue ('@nr');
	my $vid = $local_definition_node->findvalue ('@vid');
	# search for the Definiens following this node, if any
	my $next = $node->nextNonBlankSibling ();
	# $definition_nr_to_absnum{$nr} = $i;
	$definition_vid_to_absnum{$vid} = $i;
	# $definition_vid_to_thmnum{$vid} = 0;
      }
    }

    # deal with Definiens elements corresponding to Definition
    # elements that we've already seen -- record their relative ordering
    if ($node_name eq 'DefTheorem') {
      my ($prop_node) = $node->findnodes ('Proposition');
      unless (defined $prop_node) {
	die "Weird: a DefTheorem node (item $i) lacks a Proposition child element";
      }
      if ($prop_node->exists ('@vid')) {
	my $vid = $prop_node->findvalue ('@vid');
	# ensure that we really have seen this before
	unless (defined $definition_vid_to_absnum{$vid}) {
	  die "DefTheorem/Proposition with vid = $vid has not been previously registered!";
	}
      }
    }

    # register theorems that get referred to later in the article
    if ($node_name eq 'JustifiedTheorem' or $node_name eq 'Proposition') {
      my $proposition_node;
      if ($node_name eq 'JustifiedTheorem') {
	($proposition_node) = $node->findnodes ('Proposition[position()=1]');
      } else {
	$proposition_node = $node;
      }

      if (defined $proposition_node) {
	if ($proposition_node->exists ('@nr') && $proposition_node->exists ('@vid')) {
	  my $nr = $proposition_node->findvalue ('@nr');
	  my $vid = $proposition_node->findvalue ('@vid');
	  # DEBUG
	  warn ("we found a theorem that gets referred to later! its nr is $nr and its vid is $vid");
	  $theorem_nr_to_absnum{$nr} = $i;
	  $theorem_vid_to_absnum{$vid} = $i;	
	}
      } else {
	die "Weird: a JustiiedTheorem without a Proposition child element? Why?";
      }
    }

    # find the beginning
    my ($begin_line, $begin_col);
    if ($node_name eq 'DefinitionBlock' ||
	$node_name eq 'SchemeBlock' ||
        $node_name eq 'RegistrationBlock' ||
	$node_name eq 'NotationBlock' ||
        $node_name eq 'Proposition') {

      ($begin_line,$begin_col) = line_and_column ($node);

    } else { # JustifiedTheorem
      my ($theorem_proposition) = $node->findnodes ('Proposition[position()=1]');
      unless (defined ($theorem_proposition)) {
	die ("Weird: node $i, a JustifiedTheorem, lacks a Proposition child element");
      }
      ($begin_line, $begin_col) = line_and_column ($theorem_proposition);
    }

    # now find the end, if there is such a thing in the text
    unless ($node_name eq 'DefTheorem') {
      my ($end_line, $end_col);
      my $last_endposition_child;

      # we need to look at its proof
      if ($node_name eq 'Proposition') {
	my $next = $node->nextNonBlankSibling ();
	unless (defined ($next)) {
	  die ("Weird: node $i, a Proposition, is not followed by a sibling!");
	}
	my $next_name = $next->nodeName ();
	if ($next_name eq 'Proof') {
	  ($last_endposition_child)
	    = $next->findnodes ('EndPosition[position()=last()]');
	  # die ("Weird: the next sibling of node $i, a Proposition, is not a Proof element! It is a $next_name element, somehow");
	} elsif ($next_name eq 'By'
		 || $next_name eq 'From') {
	  my ($last_ref) = $next->findnodes ('Ref[position()=last()]');
	  if (defined ($last_ref)) {
	    $last_endposition_child = $last_ref;
	  } else {
	    # die ("Weird: node $i, a Proposition, is immediately justified, but the justification lacks a Ref child element!");
	    $last_endposition_child = $next;
	  }
	}
      } elsif ($node_name eq 'JustifiedTheorem') {
	my ($proof) = $node->findnodes ('Proof');
	my ($by_or_from) = $node->findnodes ('By | From');
	if (defined ($proof)) {
	  ($last_endposition_child)
	    = $proof->findnodes ('EndPosition[position()=last()]');
	} elsif (defined ($by_or_from)) {
	  my ($last_ref) = $by_or_from->findnodes ('Ref[position()=last()]');
	  if (defined ($last_ref)) {
	    $last_endposition_child = $last_ref;
	  } else {
	    $last_endposition_child = $by_or_from;
	    # die ("Node $i, a JustifiedTheorem, is immediately justified, but no statements are mentioned after the by/from keyword!");
	  }
	} else {
	  # this is the case of cancelled theorems
	  if ($node->exists ('SkippedProof')) { # toplevel skipped proof
	    my ($prop_node) = $node->findnodes ('Proposition');
	    $last_endposition_child = $prop_node;
	  } else {
	    die ("Node $i, a JustifiedTheorem, lacks a Proof as well as a SkippedProof, nor is it immediately justified by a By or From statement");
	  }
	}
      } else {
	($last_endposition_child)
	  = $node->findnodes ('EndPosition[position()=last()]');
      }

      unless (defined ($last_endposition_child)) {
	die ("Weird: node $i (a $node_name) lacks an EndPosition child element");
      }
      ($end_line,$end_col) = line_and_column ($last_endposition_child);

      # kludge: EndPosition information for Schemes differs from all
      # other elements: it is off by one: it includes the final
      # semicolon of the "end;", whereas other elements end at "end".
      if ($node_name eq 'SchemeBlock') {
	$end_col--;
      }

      # kludge: the end column information for theorems is off by three.
      # Sometimes.  (!)
      # if ($node_name eq 'JustifiedTheorem') {
      #   $begin_col = $begin_col + 3;
      #   # $begin_col = position_of_theorem_keyword_before_pos ($begin_line, $begin_col);
      # }

      # look into the node to find references that might need to be
      # rewritten.  First, distinguish between unexported toplevel
      # theorems and the rest; for the former, the references to be
      # gathered are *not* contained within the $node, but rather in its
      # following sibling.
      my $ref_containing_node;
      if ($node_name eq 'Proposition') {
	my $next = $node->nextNonBlankSibling ();
	my $next_name = $next->nodeName ();
	if ($next_name eq 'Proof') {
	  $ref_containing_node = $next;
	} else {
	  $ref_containing_node = $node; # there's no following proof; there's no need to rewrite references
	}
      } else {
	$ref_containing_node = $node;
      }

      # gather all local schemes
      my @local_schemes = ();
      my @local_scheme_nodes = $ref_containing_node->findnodes ('.//From');
      # DEBUG
      warn ("this node has " . scalar (@local_scheme_nodes) . " local scheme nodes");
      foreach my $local_scheme_node (@local_scheme_nodes) {
	my $articlenr = $local_scheme_node->findvalue ('@articlenr');
	# DEBUG
	warn ("articlenr of this From node is $articlenr");
	if ($articlenr == 0) {
	  my $local_scheme_line = $local_scheme_node->findvalue ('@line');
	  my $local_scheme_col = $local_scheme_node->findvalue ('@col');
	  my $local_scheme_sch_num = $local_scheme_node->findvalue ('@absnr');
	  my $local_scheme_abs_num = $scheme_num_to_abs_num{$local_scheme_sch_num};
	  my @local_scheme_triple = ($local_scheme_line, $local_scheme_col, $local_scheme_abs_num);
	  push (@local_schemes, \@local_scheme_triple);
	  # DEBUG
	  warn ("we found a scheme use starting at line $local_scheme_line and column $local_scheme_col, scheme $local_scheme_sch_num in the article, which is item number $local_scheme_abs_num");
	}
      }

      my @local_definitions = ();
      my @local_ref_nodes = $ref_containing_node->findnodes ('.//Ref');
      # DEBUG
      warn ("this node has " . scalar (@local_ref_nodes) . " Ref elements");
      foreach my $ref_node (@local_ref_nodes) {
	if ($ref_node->exists ('@aid')) {
	  # DEBUG
	  warn ("This ref node points to something outside the current article");
	} else {
	  # DEBUG
	  warn ("This ref node points to something in the current article");
	  my $vid = $ref_node->findvalue ('@vid');
	  my $absnum = $definition_vid_to_absnum{$vid};
	  my $thm_num = $definition_vid_to_thmnum{$vid};
	  if (defined ($absnum) && defined ($thm_num)) {
	    # DEBUG
	    warn ("this article-internal ref points to absolute item $absnum and theorem $thm_num of whatever definitionblock introduced it");
	    my $line = $ref_node->findvalue ('@line');
	    my $col = $ref_node->findvalue ('@col');
	    my @local_definition_info = ($line,$col,$absnum,$thm_num);
	    push (@local_definitions, \@local_definition_info);
	  }
	}
      }

      my @local_theorems = ();
      @local_ref_nodes = $ref_containing_node->findnodes ('.//Ref');
      # DEBUG
      warn ("searching for theorem references; this node has " . scalar (@local_ref_nodes) . " Ref elements");
      foreach my $ref_node (@local_ref_nodes) {
	if ($ref_node->exists ('@aid')) {
	  # DEBUG
	  warn ("This ref node points to something outside the current article");
	} else {
	  # DEBUG
	  warn ("This ref node points to something in the current article");
	  my $nr = $ref_node->findvalue ('@nr');
	  my $vid = $ref_node->findvalue ('@vid');
	  my $theorem_nr_absnum = $theorem_nr_to_absnum{$nr};
	  my $theorem_vid_absnum = $theorem_vid_to_absnum{$vid};
	  if (defined ($theorem_nr_absnum) && defined ($theorem_vid_absnum)) { # this Ref points to an article-local theorem
	    # DEBUG
	    warn ("wow");
	    warn ("this article-internal ref points to theorem_nr_absnum $theorem_nr_absnum and theorem_vid_absnum $theorem_vid_absnum");
	    if ($theorem_nr_absnum == $theorem_vid_absnum) { # sanity check
	      my $line = $ref_node->findvalue ('@line');
	      my $col = $ref_node->findvalue ('@col');
	      my @local_theorem_triple = ($line,$col,$theorem_nr_absnum);
	      push (@local_theorems, \@local_theorem_triple);
	    }
	  }
	}
      }

      # compute any lost "pretext" information
      # my $pretext
      #   = pretext_from_item_type_and_beginning ($node_name, $begin_line, $begin_col, $node);

      # check for whether we're dealing with one of those annoying unexported toplevel theorems, for which we need to know its label
      my $label;
      if ($node_name eq 'Proposition') {
	my $vid = $node->findvalue ('@vid');
	# DEBUG
	warn ("unexported toplevel theorem with vid $vid...");
	$label = $vid_table{$vid};
	# DEBUG
	warn ("unexported toplevel theorem has label $label...");
      } else {
	$label = '';
      }

      my $node_keyword;
      if ($node_name eq 'JustifiedTheorem') {
	if ($node->exists ('SkippedProof')) {
	  $node_keyword = 'canceled';
	} else {
	  $node_keyword = 'theorem';	
	}
      } elsif ($node_name eq 'Proposition') {
	$node_keyword = 'proposition';
      } elsif ($node_name eq 'SchemeBlock') {
	$node_keyword = 'scheme';
      } elsif ($node_name eq 'RegistrationBlock') {
	$node_keyword = 'registration';
      } elsif ($node_name eq 'DefinitionBlock') {
	$node_keyword = 'definition';
      } elsif ($node_name eq 'NotationBlock') {
	$node_keyword = 'notation';
      }

      my $text
	= extract_article_region_replacing_schemes_and_definitions_and_theorems ($node_keyword, $label, $begin_line, $begin_col, $end_line, $end_col, \@local_schemes, \@local_definitions, \@local_theorems);
      chomp $text;
      print ("Item $i: $node_name: ($begin_line,$begin_col)-($end_line,$end_col)\n");
      print ("======================================================================\n");
      print ("$text");
      print (";\n");
      print ("======================================================================\n");

      # DEBUG
      warn ("Exporting...");
      export_item ($i, $begin_line, $text); # don't start at 0
    }
  }
}

itemize ();

######################################################################
### Cleanup
######################################################################

if ($cleanup_afterward) {
  remove_tree ($workdir);
  # according to File::Path, error handling for remove_tree is done
  # via the Carp module, and not through the return value (which just
  # counts the number of files and directories removed).  Deferring to
  # this modules method for error handling is not ideal, but I'm too
  # lazy to investigate how to take over error handling and reporting;
  # in any case, how to do that is described in the File::Path
  # documentation.
} else {
  warn "Not clearning up the work directory; auxiliary files can be found in the directory\n\n  $workdir\n\nfor your inspection.";
}

# separate_theorems ();


# my $reservations_ref = split_reservations ();
# my @reservations = @{$reservations_ref};
# foreach my $reservation (@reservations) {
#   print "$reservation\n";
# }

__END__

=head1 NAME

itemize – Decompose a mizar article into its constituent parts

=head1 VERSION

Alpha!

=head1 USAGE

  itemize.pl [options] ARTICLE

=head1 REQUIRED ARGUMENTS

=over

=item <ARTICLE>

ARTICLE should be the name of an article.  If ARTICLE ends with
".miz", then the part of the article before the ".miz" will be treated
as the name of the article.

ARTICLE will be looked for in the directory specified by the
--article-source-dir option.  If that option is unset, then the 'mml'
subdirectory of whatever is specified by the MIZFILES environment
variable will be used.

ARTICLE must be at most 1 but at most 8 characters long, all
alphanumeric (though the underscore character '_' is permitted)
excluding an optional ".miz" file extension.

=for Euclid:
     ARTICLE.type: /^[A-Za-z0-9_]{1,8}(\.miz)?/
     ARTICLE.type.error:   Article must be at most 8 characters long, all alphanumeric (or '_'); it may end in '.miz', and this is not counted in the limit of 8 characters.  You supplied 'ARTICLE'.

=back

=head1 OPTIONS

=over

=item --article-source-dir=<DIRECTORY>

Take ARTICLE from DIRECTORY.  Both relative and absolute paths are
acceptable.

If this option is unset, then the MIZFILES environment variable will
be consulted, and the subdirectory 'mml' will be the source for
ARTICLE.

=item --result-dir=<RESULT-DIRECTORY>

Make a local mizar database for ARTICLE in RESULT-DIRECTORY, which
should be an absolute path.  The database will itself be a subdirecory
of RESULT-DIRECTORY called by the same name as ARTICLE; the database
itself will contain subdirectories 'prel' and 'text'.

RESULT-DIRECTORY, if unset, defaults to the current directory.  If
set, it should be a path; it can be either an absolute path (beginning
with a forward slash '/') or a relative path (i.e., anything that is
not an absolute path).  In either case, it is up to the user to ensure
that, if RESULT-DIRECTORY is set, that the directory exists and is
writable.

=for Euclid:

=item --emacs-lisp-dir=<ELISP-DIR>

The directory in which to look for the Emacs Lisp code that this
program uses.  The default is to use the current directory.

=for Euclid:
     ELISP-DIR.default: '.'

=item --with-stylesheets-in=<STYLESHEET-DIRECTORY>

The directory that contains the relevant stylesheets applied to the
article XML.  Both absolute and relative paths may be supplied.  If
this option is unset, then the current directory ('.') is used.

=for Euclid:
     STYLESHEET-DIRECTORY.default: '.'

=item --no-cleanup

Don't remove auxiliary, intermediate files generated for the sake of
decomposing the given article. (By default, all such files will be
deleted before terminating.)

=item --verbose

Indicate what's going on at notable points in the computation.

=item --version

=item --usage

=item --help

=item --man

Print the usual program information.

=back

=head1 DESCRIPTION

This program divides a mizar article into its constituent pieces.

A directory called by the same name as ARTICLE will be created in the
directory specified by the --result-dir option.  The default is to use
the current directory.

Upon termination, the directory ARTICLE will be a mizar "working
directory" containing subdirectories "dict", "prel", and "text".
Inside the "text" subdirectory there will be as many new mizar
articles as there are items in ARTICLE.  The "dict" subdirectory will
likewise contain as vocabulary files as there are items in ARTICLE.
The "prel" subdirectory will contain the results of calling miz2prel
on each of the standalone articles.

=head1 DIAGNOSTICS

Always returns 0, if it terminates cleanly at all.

(Obviously, this is useless.  This will change in future versions as
the program matures.)

=head1 CONFIGURATION AND ENVIRONMENT

This program uses the MIZFILES environment variable.

=head1 DEPENDENCIES

=head2 PERL DEPENDENCIES

=head3 Non-standard modules

=over

=item File::Tempdir

=item File::Spec

=item Getopt::Euclid (>= 0.2.3)

=item File::Copy

=item File::Path

=back

=head2 NON-PERL DEPENDENCIES

=over

=item reservations.el

Emacs Lisp code for extracting content from the supplied ARTICLE.

=back

=head1 INCOMPATIBILITIES

None are known.

=head1 BUGS AND LIMITATIONS

Breaking up article is very slow.  There are lots of opportunities for
optimization.

This module currently does not handle articles that have global set or
reconsider statements.  If any article with such features is detected,
further processing stops.

Please report problems to Jesse Alama (jesse.alama@gmail.com). Patches
are welcome.

=head1 AUTHORS

Jesse Alama (jesse.alama@gmail.com)

=head1 ACKNOWLEDGEMENTS

Thanks to Josef Urban, as always, for his mizar-ly support and advice
and to Karol Pąk for his essential JA and JA1 mizar tools.

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2010 Jesse Alama (jesse.alama@gmail.com). All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
