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
use File::Spec::Functions qw / catfile catdir /;
use File::Copy qw / copy move /;
use File::Path qw / remove_tree /;
use XML::LibXML;
use Fatal qw / open /;
use List::MoreUtils qw / all /;

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
my $article_evl = $article_name . '.evl';
my $article_miz_path = catfile ($article_source_dir, $article_miz);
my $article_err_path = catfile ($article_source_dir, $article_err);
my $article_tmp_path = catfile ($article_source_dir, $article_tmp);
my $article_evl_path = catfile ($article_source_dir, $article_evl);

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
my $article_text_dir = catdir ($local_db, 'text');
my $article_prel_dir = catdir ($local_db, 'prel');

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
### 2. Run JA1, edtfile, overwrite the non-JA1'd .miz, and load it
###
### 3. Verify (and generate article XML)
###
### 4. Generate the absolute reference version of the generated XML
###
### 5. Load the .idx file
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


### 2. Run JA1, edtfile, overwrite the non-JA1'd .miz, and load it

# JA1
system ("JA1 -q -s -l $article_miz > /dev/null 2> /dev/null");
unless ($? == 0) {
  die "Error: Something went wrong when calling JA1 on $article_name: the error was\n\n$!";
}
if (-s $article_err) {
  die "Error: although the JA1 tool returned successfully, it nonetheless generated a non-empty error file";
}

# edtfile
system ("edtfile $article_name > /dev/null 2> /dev/null");
unless ($? == 0) {
  die ("Error: Something went wrong during the call to edtfile on $article_name:\n\n  $!");
}
if (-s $article_err) {
  die "Error: although the edtfile tool returned successfully, it nonetheless generated a non-empty error file";
}

# sanity check
unless (-e $article_tmp) {
  die "Error: the edtfile tool did not generate the expected file '$article_tmp'";
}
unless (-r $article_tmp) {
  die "Error: the file generated by the edtfile tool, '$article_tmp', is not readable";
}

# rename
move ($article_tmp, $article_miz) == 1
  or die "Error: unable to rename the temporary file\n\n  $article_tmp\n\nto\n\n  $article_miz\n\nin the work directory\n\n  $workdir .\n\nThe error was\n\n  $!";

# load
my @article_lines = ();

open my $miz, '<', $article_in_workdir # we already 'know' this is readable
  or die "Couldn't open an input file handle for $article_miz_path!";
while (defined (my $line = <$miz>)) {
  chomp $line;
  push (@article_lines, $line);
}
close $miz
  or die "Couldn't close the input file handle for $article_miz_path!";

my $num_article_lines = scalar @article_lines;

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

### 5. Load the idx file
my $article_idx = $article_name . '.idx';
my %idx_table = ();

# sanity
unless (-e $article_idx) {
  die "IDX file doesn't exist in the working directory ($workdir)!";
}
unless (-r $article_idx) {
  die "IDX file in the working directory ($workdir) is not readable!";
}

my $idx_parser = XML::LibXML->new();
my $idx_doc = $idx_parser->parse_file ($article_idx);
my $symbol_xpath_query 
  = 'Symbols/Symbol'; # this might need to change in the future
my @symbols = $idx_doc->findnodes ($symbol_xpath_query);
foreach my $symbol (@symbols) {
  my $vid = $symbol->findvalue ('@nr');
  my $name = $symbol->findvalue ('@name');
  $idx_table{$vid} = $name;
}

######################################################################
### We're done setting up the work directory; now we can use the
### intermediate files we just generated to split up the given article
### into its constituent items.
######################################################################

sub fetch_directive {
  my $directive = shift;

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

my @mml_lar = ();

# ensure that we can read mml.lar
my $mml_lar_path = catfile ($mizfiles, 'mml.lar');
unless (-e $mml_lar_path) {
  die "The file mml.lar doesn't exist under $mizfiles!";
}
unless (-r $mml_lar_path) {
  die "The file mml.lar under $mizfiles is not readable!";
}

sub read_mml_lar {
  open my $mmllar, '<', $mml_lar_path
    or die "mml.lar cannot be opened: $!";
  while (<$mmllar>) {
    chomp;
    push (@mml_lar, $_);
  }
  close ($mmllar)
    or die "Can't close read-only filehandle for mml.lar: $!";
  return;
}

read_mml_lar ();

sub export_item {
  my $number = shift;
  my $begin_line = shift;
  my $text = shift;

  my $item_path = catfile ($article_text_dir, "item$number.miz");
  open (ITEM_MIZ, q{>}, $item_path)
    or die ("Unable to open an output filehandle at $item_path:\n\n  $!");
  print ITEM_MIZ ("environ\n");

  # vocabularies are easy
  my @this_item_vocabularies = @vocabularies;
  unless (@this_item_vocabularies == 0) {
    print ITEM_MIZ ("vocabularies " . join (', ', @this_item_vocabularies) . ";");
    print ITEM_MIZ ("\n");
  }

  # notations
  my @this_item_notations = @notations;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_notations, "ITEM$i");
  }
  unless (@this_item_notations == 0) {
    print ITEM_MIZ ("notations " . join (', ', @this_item_notations) . ";");
    print ITEM_MIZ ("\n");
  }

  # constructors
  my @this_item_constructors = @constructors;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_constructors, "ITEM$i");
  }
  unless (@this_item_constructors == 0) {
    print ITEM_MIZ ("constructors " . join (', ', @this_item_constructors) . ";");
    print ITEM_MIZ ("\n");
  }

  # registrations
  my @this_item_registrations = @registrations;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_registrations, "ITEM$i");
  }
  unless (@this_item_registrations == 0) {
    print ITEM_MIZ ("registrations " . join (', ', @this_item_registrations) . ";");
    print ITEM_MIZ ("\n");
  }

  # requirements is "easy"
  my @this_item_requirements = @requirements;
  unless (@this_item_requirements == 0) {
    print ITEM_MIZ ("requirements " . join (', ', @this_item_requirements) . ";");
    print ITEM_MIZ ("\n");
  }

  # handle the definitions directive just like the constructors directive
  my @this_item_definitions = @definitions;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_definitions, "ITEM$i");
  }
  unless (@this_item_definitions == 0) {
    print ITEM_MIZ ("definitions " . join (', ', @this_item_definitions) . ";");
    print ITEM_MIZ ("\n");
  }

  # theorems
  my @this_item_theorems = @theorems;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_theorems, "ITEM$i");
  }
  unless (@this_item_theorems == 0) {
    print ITEM_MIZ ("theorems " . join (', ', @this_item_theorems) . ";");
    print ITEM_MIZ ("\n");
  }

  # schemes
  my @this_item_schemes = @schemes;
  foreach my $i (1 .. $number - 1) {
    push (@this_item_schemes, $i);
  }
  unless (@this_item_schemes == 0) {
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

sub miz_xml {
  my $parser = XML::LibXML->new();
  return ($parser->parse_file($article_xml_absrefs));
}

my %reservation_table = ();

sub init_reservation_table {
  foreach my $line_num (0 .. $num_article_lines - 1) {
    my $miz_line = $article_lines[$line_num];
    if ($miz_line =~ m/^reserve[ ]+[^ ]|[ ]+reserve[ ][^ ]/g) {
#                                                          ^ 'g' here; see below
      my $after_reserve = pos $miz_line;
      my $line_up_to_match = substr $miz_line, 0, $after_reserve;
      unless ($line_up_to_match =~ m/::/) {
#                                      ^ no 'g' in match here...
	if ($miz_line =~ m/\G[^;]+;/g) {
#                          ^ ...so '\G' here refers to the penultimate match
	  my $semicolon = pos $miz_line;
	  my $reserve
	    = substr $miz_line,
                     $after_reserve - 1,
#                                   ^ - 1 for the previous non-whitespace char
		     $semicolon - $after_reserve + 1;
#                                                ^ + 1 for the semicolon
	  # DEBUG
	  warn "Computed reservation $reserve";
	  $reservation_table{$line_num} = $reserve;
	}
      }
    }
  }
  return;
}

sub reservations_from_xml {
  my $doc = miz_xml ();
  my @reservations = $doc->findnodes ('/Reservation');
  return (\@reservations);
}

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

sub from_keyword_to_position {
  my $keyword = shift;
  my $line = shift;
  my $col = shift;
  # find the maximal line and column in @article_lines before column
  # $col of line $line that starts with $keyword.

  # first, check whether the current line already contains the keyword.
  my $first_line = $article_lines[$line-1]; # count lines from 1
  my $first_line_length = length $first_line;

  # sanity
  if ($col > $first_line_length) {
    die "We cannot inspect column $col of line $line, because there aren't that many columns in the line!";
  }

  my $truncated_first_line = substr $first_line, 0, $col - 1; # from 1, not 0

  my $target_line_num = $line;
  my $pos;

  my $target_line = undef;

  until (defined $target_line) {
    $target_line_num--;

    my $current_line;
    if ($target_line_num == $line - 1) { # look at the truncated first line
      $current_line = $truncated_first_line;
    } else {
      $current_line = $article_lines[$target_line_num];
    }

    my $match_pos;
    if ($current_line =~ m/^$keyword|[ ]$keyword$|[ ]$keyword[ ]/g) {
      # check this this occurrence of $keyword isn't commented out
      my $match_pos = pos $current_line;
      my $truncated_current_line = substr $current_line, 0, $match_pos;
      if ($truncated_current_line !~ m/::/) {
	$target_line = $current_line;
      }
    }
  }

  # we have found our line; now find the LAST use of $keyword
  while ($target_line =~ m/^$keyword|[ ]$keyword$|[ ]$keyword[ ]/g) {
    $pos = pos $target_line;
  }

  $target_line_num++; # off by one?!

  return ($target_line_num, $pos);
}

sub theorem_before_position {
  my $end_line = shift;
  my $end_col = shift;
  my ($begin_line,$begin_col)
    = from_keyword_to_position ('theorem', $end_line, $end_col);
  # DEBUG
  warn "For this theorem, we started at line $end_line and column $end_col";
  warn "For this theorem, the begin_line is $begin_line and the begin_col is $begin_col";
  my $theorem = extract_region ($begin_line,$begin_col,$end_line,$end_col);
  # DEBUG
  warn "Just extracted theorem: $theorem";
  return $theorem;
}

sub scheme_before_position {
  my $end_line = shift;
  my $end_col = shift;
  my ($begin_line,$begin_col)
    = from_keyword_to_position ('scheme', $end_line, $end_col);
  my $scheme = extract_region ($begin_line,$begin_col,$end_line,$end_col);
  # DEBUG
  warn "here's our scheme: $scheme";
  return $scheme;
}

sub extract_region {
  my $beg_line = shift;
  my $beg_col = shift;
  my $end_line = shift;
  my $end_col = shift;

  my @buffer
    = @{extract_region_as_array ($beg_line, $beg_col, $end_line, $end_col)};

  return join ("\n", @buffer);
}

sub extract_region_as_array {
  my $beg_line = shift;
  my $beg_col = shift;
  my $end_line = shift;
  my $end_col = shift;

  # sanity checking
  if ($beg_line < 0) {
    die "Cannot extract a line with a negative line number\n(we were asked for the region starting from line $beg_line)";
  }
  if ($end_line > $num_article_lines) {
    die "Cannot extract a line beyond the end of the file\n(there are $num_article_lines total, but we were asked for the region up to line $end_line)";
  }

  my @buffer = ();

  # get the first line
  my $first_line_full
    = $article_lines[$beg_line-1]; # count lines from 1
  my $first_line_length = length $first_line_full;
  if ($beg_col <= $first_line_length) {
    if ($beg_line == $end_line) {
      push (@buffer, substr $first_line_full, $beg_col, $end_col - $beg_col + 1);
    } else {
      push (@buffer, substr $first_line_full, $beg_col); # count from 1
    }
  } else {
    die "Cannot extract text from beyond the end of the line\n(the line of the file that was first requested,\n\n  $first_line_full\n\nhas length $first_line_length, but we were asked to start at column $beg_col)";
  }

  # get intermediate lines between $beg_line and $end_line
  foreach my $i ($beg_line .. $end_line - 1) {
    push (@buffer, $article_lines[$i]);
  }

  if ($beg_line != $end_line) {
    # get the last line
    my $last_line_full = $article_lines[$end_line-1]; # count lines from 1
    my $last_line_length = length $last_line_full;
    if ($end_col < $last_line_length) {
      push (@buffer, substr $last_line_full, 0, $end_col); # count cols from 0
    } else {
      die "Cannot extract text from beyond the end of the line\n(the last line of the requested region has length $last_line_length, but we were asked to extract up to column $end_col)";
    }
  }

  return \@buffer;
}

sub instruction_greater_than {
  my @instruction_a = @{$a};
  my @instruction_b = @{$b};
  my $line_a = $instruction_a[1];
  my $line_b = $instruction_b[1];
  my $col_a = $instruction_a[2];
  my $col_b = $instruction_b[2];
  if ($line_a < $line_b) {
    return 1;
  } elsif ($line_a == $line_b) {
    if ($col_a < $col_b) {
      return 1
    } elsif ($col_a == $col_b) {
      return 0;
    } else {
      return -1;
    }
  } else {
    return -1;
  }
}

sub extract_article_region_replacing_schemes_and_definitions_and_theorems {
  my $item_kind = shift;
  my $label = shift;
  my $bl = shift;
  my $bc = shift;
  my $el = shift;
  my $ec = shift;
  my @schemes = @{shift ()};
  my @definitions = @{shift ()};
  my @theorems = @{shift ()};

  my @instructions = ();

  foreach my $scheme_info_ref (@schemes) {
    my @scheme_info = @{$scheme_info_ref};
    my @instruction = ('scheme');
    push (@instruction, @scheme_info);
    push (@instructions, \@instruction);
  }
  foreach my $definition_info_ref (@definitions) {
    my @definition_info = @{$definition_info_ref};
    my @instruction = ('definition');
    push (@instruction, @definition_info);
    push (@instructions, \@instruction);
  }
  foreach my $theorem_info_ref (@theorems) {
    my @theorem_info = @{$theorem_info_ref};
    my @instruction = ('theorem');
    push (@instruction, @theorem_info);
    push (@instructions, \@instruction);
  }

  # sort the instructions
  my @sorted_instructions
    = sort instruction_greater_than @instructions; # apply in REVERSE order

  # do it
  my @buffer = @{extract_region_as_array ($bl, $bc, $el, $ec)};

  # DEBUG print instructions
  print "Instructions:\n";
  foreach my $instruction_ref (@sorted_instructions) {
    my @instruction = @{$instruction_ref};
    my $instruction_type = $instruction[0];
    my $instr_line_num = $instruction[1];
    my $instr_col_num = $instruction[2];
    my $instr_label = $instruction[3];
    my $instr_item_num = $instruction[4];
    print "($instruction_type $instr_line_num $instr_col_num $instr_label $instr_item_num) in the region ($bl,$bc,$el,$ec)\n";
  }


  foreach my $instruction_ref (@sorted_instructions) {
    my @instruction = @{$instruction_ref};

    # instructions are of two kinds: scheme and theorem instructions,
    # and definition instructions.  Scheme and theorem instructions look
    # like
    #
    # (scheme <line> <column> <label> <item-number>)
    #
    # and
    #
    # (theorem <line> <column> <label> <item-number>) .
    #
    # In both of these kinds of instructions, <line> and <column> refer
    # to the place in the source article where the scheme/theorem
    # reference begins.  Thus, <line> and <column> point
    #
    # blah by Th1,XBOOLE_0:def 4;
    #         ^
    #         here
    #
    # <label> is a string representing the label of the toplevel
    # article-internal item to be replaced.  <item-number> refers to
    # the absolute item number.  Thus, continuing the example above,
    # if the sole instruction were
    #
    # (theorem 1 8 'Th1' 3)
    #
    # then
    #
    # blah by Th1,XBOOLE_0:def 4;
    #
    # would get transformed to
    #
    # blah by ITEM3:1,XBOOLE_0:def 4;
    #
    # Definition instructions have an extra piece of information:
    #
    # (definition <line> <column> <label> <item-number> <relative-item-number>
    #
    # <line>, <column>, <label>, and <item-number> mean the same thing
    # as they do for scheme and theorem instructions. The extra bit
    # <relative-item-number> refers to the number of the definition
    # within <item-number> (which is a definition).  "Definition" here
    # just means "definition block", which can have multiple
    # definitions, hence the need for the further
    # <relative-item-number> information.
    #
    # This function takes the region of the article delimited by BL, BC,
    # EL, and EC and applies the instruction.  It returns a reference to
    # the modfied article text.

    my $instruction_type = $instruction[0];
    my $instr_line_num = $instruction[1];
    my $instr_col_num = $instruction[2];
    my $instr_label = $instruction[3];
    my $instr_item_num = $instruction[4];

    # DEBUG
    print "Applying instruction ($instruction_type $instr_line_num $instr_col_num $instr_label $instr_item_num) in the region ($bl,$bc,$el,$ec)\n";
    print "The buffer looks like this:\n";
    foreach (@buffer) {
      print "$_\n";
    }

    # sanity checks
    if ($instr_line_num < 1) {
      die "The given editing instruction requests that line $instr_line_num be modified, but that's impossible (we start counting line numbers at 1)!";
    }
    if ($instr_line_num > $num_article_lines) {
      die "The given editing instruction requests that line $instr_line_num be modified, but there aren't that many lines in the article!";
    }
    if ($instr_col_num < 0) {
      die "The given editing instruction requests that column $instr_col_num be inspected, but that's negative!";
    }

    # distinguish between editing instuctions that ask us to modify
    # the first of the region.  From the first line we have (in
    # general) stripped off some initial substring, which (in general)
    # renders the column information of the editing instruction
    # incoherent, so that it needs to be adjusted.
    if ($instr_line_num == $bl) {
      $instr_col_num -= $bc;
    }

    # DEBUG
    warn "instruction column number is now $instr_col_num";

    # now adjust the instruction's line numbers.  We need to do this
    # because the information from which the editing instruction was
    # generated makes sense relative to the whole file, but we are
    # editing only a snippet of the file here.  Thus, if the editing
    # instruction says to modify line 1000 in a certain way, and we
    # are considering an item that spans lines 990 to 1010, we dealing
    # only with those 21 lines; 990 gets mapped to 0, and 1010 gets
    # mapped to 20, so line "1000" needs to get mapped to line 10.

    # DEBUG
    warn "We are asked to edit line $instr_line_num...";
    $instr_line_num -= $bl;
    # DEBUG
    warn "...which just got adjusted to $instr_line_num";

    my $line = $buffer[$instr_line_num];
    unless (defined $line) {
      die "There is no line number $instr_line_num in the current buffer\n\n@buffer\n\n!";
    }
    my $line_length = length $line;

    # more sanity checking
    if ($instr_col_num > $line_length) {
      die "The given editing instruction requests that column $instr_col_num be inspected, but there aren't that many columns in the line\n\n$line\n\nthat we're supposed to look at!";
    }

    # weird special case: the editing instruction says to go to the
    # END of the line, which doesn't really make sense.  See line 100
    # of xbool_0.miz for an example of what can go wrong.  What we
    # need to do when we detect this kind of case is adust $line so
    # that it is the first line that contains something not commented
    # out.
    #
    # this is a case where what I'm doing crucially depends on how the
    # mizar parser keeps track of whitespace.  Annoying.
    if ($instr_col_num == $line_length) {
      # DEBUG
      warn "This is the weird whitespace case!";
      $instr_line_num++;
      $line = $buffer[$instr_line_num];
      while ($line =~ /^[ ]*::/) {
	$instr_line_num++;
	$line = $buffer[$instr_line_num];
      }

      # we've found the right line; now go to the right column
      $line =~ m/^[ ]*[^ ]/g;
      $instr_col_num = (pos $line) - 2; # back up 2 because of the way pos works

      # DEBUG
      warn "Done dealing with the whitepsace case: the current line is $line, and the current column is $instr_col_num"
    }

    my $label_length = length $instr_label;

    # weird special case! thanks Josef :-p
    my $offset = $instruction_type eq 'scheme' ? $instr_col_num + 1
                                               : $instr_col_num - $label_length;

    my $before_line = $line;
    if ($instruction_type eq 'scheme') {
      $line =~ s/^(.{$offset})$instr_label(.*)$/$1ITEM$instr_item_num:sch 1$2/;
    } elsif ($instruction_type eq 'theorem') {
      $line =~ s/^(.{$offset})$instr_label(.*)$/$1ITEM$instr_item_num:1$2/;
    } elsif ($instruction_type eq 'definition') {
      my $instr_relative_item_number = $instruction[5];
      $line =~ s/^(.{$offset})$instr_label(.*)$/$1ITEM$instr_item_num:def $instr_relative_item_number$2/;
    } else {
      die "Unknown instruction type $instruction_type";
    }

    # DEBUG
    print "line after the instuction:\n\n$line\n";

    if ($before_line eq $line) {
      die "We were supposed to do an editig operation, but NOTHING HAPPENED!";
    }

    $buffer[$instr_line_num] = $line;
  }

  return join ("\n", @buffer);
}

init_reservation_table ();

my %vid_to_theorem_num = ();
my %theorem_num_to_vid = ();
my %vid_to_diffuse_lemma_num = ();
my %diffuse_lemmas_to_vid = ();
my %vid_to_scheme_num = ();
my %scheme_num_to_vid = ();

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

sub pretext_from_item_type_and_beginning {
  my $item_type = shift;
  my $begin_line = shift;
  my $begin_col = shift;
  my $item_node = shift;

  # DEBUG
  warn "Looking for pretext starting from $begin_line and $begin_col";

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
    # my $theorem = extract_toplevel_unexported_theorem_with_label ($begin_line, $begin_col, $prop_label);
    # $pretext = "theorem $theorem\n";
    $pretext = "theorem ";
  } elsif ($item_type eq 'SchemeBlock') {
    $pretext = 'scheme ' . scheme_before_position ($begin_line, $begin_col);
  } elsif ($item_type eq 'NotationBlock') {
    $pretext = "notation\n";
  } elsif ($item_type eq 'DefinitionBlock') {
    $pretext = "definition\n";
  } elsif ($item_type eq 'RegistrationBlock') {
    $pretext = "registration\n";
  } else {
    $pretext = '';
  }
  return $pretext;
}

my %scheme_num_to_abs_num = ();
my %definition_nr_to_absnum = ();
my %definition_vid_to_absnum = ();
my %definition_vid_to_thmnum = ();
my %theorem_nr_to_absnum = ();
my %theorem_vid_to_absnum = ();

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

sub load_deftheorems {
  my $doc = miz_xml ();

  my $last_deftheorem_xpath_query
    = '//Article/DefTheorem[name(following-sibling::*) != "DefTheorem"]';

  my @final_deftheorem_nodes = $doc->findnodes ($last_deftheorem_xpath_query);
  
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
  }

  return;
}

load_deftheorems ();

my @nodes = ();

sub load_items {
  my @item_xpaths = ('JustifiedTheorem',
		     'Proposition',
		     'DefinitionBlock',
		     'SchemeBlock',
		     'RegistrationBlock',
		     'NotationBlock',
		     'Defpred',
		     'Deffunc',
		     'Reconsider',
		     'Set');
  my @toplevel_item_xpaths = map { "Article/$_" } @item_xpaths;
  my $query = join (' | ', @toplevel_item_xpaths);
  my $doc = miz_xml ();
  @nodes = $doc->findnodes ($query);
  return;
}

load_items ();

sub itemize {

  my $scheme_num = 0;
  foreach my $i (1 .. scalar (@nodes)) {
    my $node = $nodes[$i-1];
    my $node_name = $node->nodeName;

    # register a scheme, if necessary
    if ($node_name eq 'SchemeBlock') {
      $scheme_num++;
      $scheme_num_to_abs_num{$scheme_num} = $i;
      my $vid = $node->findvalue ('@vid');
      unless (defined $vid) {
	die "SchemeBlock node lacks a vid!";
      }
      $scheme_num_to_vid{$scheme_num} = $vid;
    }

    # register definitions, making sure to count the ones that
    # generate DefTheorems
    if ($node_name eq 'DefinitionBlock') {
      my @local_definition_nodes = $node->findnodes ('.//Definition');
      foreach my $local_definition_node (@local_definition_nodes) {
	my $vid = $local_definition_node->findvalue ('@vid');
	# search for the Definiens following this node, if any
	my $next = $node->nextNonBlankSibling ();
	$definition_vid_to_absnum{$vid} = $i;
      }
    }

    if ($node_name eq 'Defpred') {
      warn "Node $i is a global defpred statement; we don't know how to handle these yet.";
    }

    if ($node_name eq 'Deffunc') {
      warn "Node $i is a global deffunc statement; we don't know how to handle these yet.";
    }

    if ($node_name eq 'Reconsider') {
      warn "Node $i is a global reconsider statement; we don't know how to handle these yet.";
    }

    if ($node_name eq 'Set') {
      warn "Node $i is a global reconsider statement; we don't know how to handle these yet.";
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
      # weird: this might not be accurate!
      # ($begin_line, $begin_col)
      # 	= from_keyword_to_position ('theorem', $begin_line, $begin_col);
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
	  my $scheme_vid = $scheme_num_to_vid{$local_scheme_sch_num};
	  my $scheme_label = $idx_table{$scheme_vid};
	  # DEBUG
	  warn "scheme vid is $scheme_vid; its label is $scheme_label";
	  my @local_scheme_info = ($local_scheme_line, $local_scheme_col, $scheme_label, $local_scheme_abs_num);
	  push (@local_schemes, \@local_scheme_info);
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
	    my $def_label = $idx_table{$vid};
	    # DEBUG
	    warn "it's vid is $vid; its label is $def_label";
	    my $line = $ref_node->findvalue ('@line');
	    my $col = $ref_node->findvalue ('@col');
	    my @local_definition_info = ($line,$col,$def_label,$absnum,$thm_num);
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
	      my $th_label = $idx_table{$vid};
	      # DEBUG
	      warn "the vid of this theorem is $vid; its label is $th_label";
	      my @local_theorem_info = ($line,$col,$th_label,$theorem_nr_absnum);
	      push (@local_theorems, \@local_theorem_info);
	    }
	  }
	}
      }

      # compute any lost "pretext" information
      my $pretext
	 = pretext_from_item_type_and_beginning ($node_name, $begin_line, $begin_col, $node);

      # DEBUG
      print "the pretext is '$pretext'\n";

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
      print ("$pretext$text");
      print (";\n");
      print ("======================================================================\n");

      export_item ($i, $begin_line, "$pretext$text");
    }
  }

  return scalar @nodes;
}

my $num_items = itemize ();

######################################################################
### Incrementally verify and export each of the generated items
######################################################################

sub verify_item_with_number {
  my $item_number = shift;

  if ($be_verbose) {
    print "Verifying article fragment #$item_number\n";
  }

  my $miz = catfile ('text', "item$item_number.miz");
  my $err = catfile ('text', "item$item_number.err");

  # where we'll work
  chdir $local_db;

  # sanity check: article exists and is readable
  unless (-e $miz) {
    die "Error: the mizar article for item number $item_number does not exist under $article_text_dir!";
  }
  unless (-r $miz) {
    die "Error: the mizar article for item number $item_number under $article_text_dir is not readable!";
  }

  # accomodate
  system ("accom -q -s -l $miz > /dev/null 2> /dev/null");

  # more sanity checking
  unless ($? == 0) {
    die "Error: Something went wrong when calling the accomodator on $miz under $article_text_dir: the error was\n\n$!";
  }
  if (-e $err && -s $err) {
    die "Error: although the accomodator returned successfully when run on $miz under $article_text_dir,\\it nonetheless generated a non-empty error file";
  }

  # verify
  system ("verifier -q -s -l $miz > /dev/null 2> /dev/null");

  # even more sanity checking
  unless ($? == 0) {
    die "Error: Something went wrong when calling the verifier on $miz under $article_text_dir: the error was\n\n$!";
  }
  if (-e $err && -s $err) {
    die "Error: although the verifier returned successfully when run on $miz under $article_text_dir,\\it nonetheless generated a non-empty error file";
  }

  return;
}

sub export_item_with_number {
  my $item_number = shift;

  if ($be_verbose) {
    print "Exporting article fragment #$item_number\n";
  }

  my $miz = catfile ('text', "item$item_number.miz");
  my $err = catfile ('text', "item$item_number.err");

  # where we'll work
  chdir $local_db;

  # sanity check: article exists and is readable
  unless (-e $miz) {
    die "Error: the mizar article for item number $item_number does not exist under $article_text_dir!";
  }
  unless (-r $miz) {
    die "Error: the mizar article for item number $item_number under $article_text_dir is not readable!";
  }

  # export
  system ("exporter -q -s -l $miz > /dev/null 2> /dev/null");
  unless ($? == 0) {
    die "Error: Something went wrong when exporting $miz under $article_text_dir: the error was\n\n$!";
  }
  if (-e $err && -s $err) {
    die "Error: although the exporter terminated successfully after working on $miz (under $article_text_dir),\na non-empty error file was generated nonetheess!";
  }

  # transfer
  system ("transfer -q -s -l $miz > /dev/null 2> /dev/null");

  # even more sanity checking
  unless ($? == 0) {
    die "Error: Something went wrong when calling the transfer tool on $miz under $article_text_dir: the error was\n\n$!";
  }
  if (-e $err && -s $err) {
    die "Error: although transfer terminated successfully after working on $miz (under $article_text_dir),\na non-empty error file was generated nonetheess!";
  }

  return;
}

sub trim_directive {
  my $directive_name = shift;
  my $extension_for_directive = shift;
  my @directive_contents = @{shift ()};
  my @trimmed = ();
  foreach my $directive_item (@directive_contents) {
    my $file_to_look_for = catfile ($article_prel_dir, "$directive_item.$extension_for_directive");
    if (grep (/^$directive_item$/i, @mml_lar)) {
      push (@trimmed, $directive_item);
    } elsif ($directive_item eq 'TARSKI') { # TARSKI is not listed in mml.lar
      push (@trimmed, $directive_item);
    } elsif (-e $file_to_look_for) {
      push (@trimmed, $directive_item);
    }
  }
  return \@trimmed;
}

sub trim_item_with_number {

  my $item_number = shift;

  if ($be_verbose) {
    print "Triming article fragment #$item_number\n";
  }

  my $miz = catfile ($article_text_dir, "item$item_number.miz");

  # sanity check: the article fragment exists and is readable
  unless (-e $miz) {
    die "Error: unable to trim article fragment $item_number because the corresponding .miz file doesn't exist under $article_text_dir!";
  }
  unless (-r $miz) {
    die "Error: unable to trim article fragment $item_number because the corresponding .miz file under $article_text_dir is not readable!";
  }

  # copy the environment
  my @notations = @notations;
  my @constructors = @constructors;
  my @registrations = @registrations;
  my @definitions = @definitions;
  my @theorems = @theorems;
  my @schemes = @schemes;

  my @earlier_item_numbers = ();
  foreach my $i (1 .. $item_number - 1) {
    push (@earlier_item_numbers, "ITEM$i");
  }

  # in addition to any directives that the original article uses,
  # conservatively start off by saying that the fragment depends on
  # ALL earlier fragments.  We'll cut that down later.
  push (@notations, @earlier_item_numbers);
  push (@constructors,@earlier_item_numbers);
  push (@registrations, @earlier_item_numbers);
  push (@definitions, @earlier_item_numbers);
  push (@theorems, @earlier_item_numbers);
  push (@schemes, @earlier_item_numbers);

  # Now that we've ballooned each of the directives, cut them down to
  # something more sensible.
  my @trimmed_notations = @{trim_directive ('notations', 'dno', \@notations)};
  my @trimmed_constructors = @{trim_directive ('constructors', 'dco', \@constructors)};
  my @trimmed_registrations = @{trim_directive ('registrations', 'dcl', \@registrations)};
  my @trimmed_definitions = @{trim_directive ('definitions', 'def', \@definitions)};
  my @trimmed_theorems = @{trim_directive ('theorems', 'the', \@theorems)};
  my @trimmed_schemes = @{trim_directive ('schemes', 'sch', \@schemes)};

  # we're going to overwrite the .miz with the trimmed environment
  open my $miz_in, '<', $miz
    or die "Coudn't open read-only filehandle for $miz: $!";
  unlink $miz;
  open my $miz_out, '>', $miz
    or die "Couldn' open write-only filehandle for $miz: $!";
  while (defined (my $line = <$miz_in>)) {
    chomp $line;
    if ($line =~ /^notations /) {
      print {$miz_out} ('notations ' . join (', ', @trimmed_notations) . ";\n")
	unless scalar @trimmed_notations == 0;
    } elsif ($line =~ /^constructors /) {
      print {$miz_out} ('constructors ' . join (', ', @trimmed_constructors) . ";\n")
	unless scalar @trimmed_constructors == 0;
    } elsif ($line =~ /^registrations /) {
      print {$miz_out} ('registrations ' . join (', ', @trimmed_registrations) . ";\n")
	unless scalar @trimmed_registrations == 0;
    } elsif ($line =~ /^definitions /) {
      print {$miz_out} ('definitions ' . join (', ', @trimmed_definitions) . ";\n")
	unless scalar @trimmed_definitions == 0;
    } elsif ($line =~ /^theorems /) {
      print {$miz_out} ('theorems ' . join (', ', @trimmed_theorems) . ";\n")
	unless scalar @trimmed_theorems == 0;
    } elsif ($line =~ /^schemes /) {
      print {$miz_out} ('schemes ' . join (', ', @trimmed_schemes) . ";\n")
	unless scalar @trimmed_schemes == 0;
    } elsif ($line =~ /^requirements /) { # special case
      print {$miz_out} ('requirements ' . join (', ', @requirements) . ";\n")
	unless scalar @requirements == 0;
    } else {
      print {$miz_out} ("$line\n");
    }
  }

  close $miz_in
    or die "Couldn't close input filehandle for $miz!";
  close $miz_out
    or die "Couldn't close output filehandle for $miz!";

  return;
}

foreach my $item_number (1 .. $num_items) {
  trim_item_with_number ($item_number);
  verify_item_with_number ($item_number);
  export_item_with_number ($item_number);
}

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
  print "Not clearning up the work directory; auxiliary files can be found in the directory\n\n  $workdir\n\nfor your inspection.\n";
}

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

=item addabsrefs.xsl

XSL stylesheet by Josef Urban for computing, from the XML generated by
the mizar verifier, a version of the same thing with more information.

=back

=head1 INCOMPATIBILITIES

Be careful with the version of envget being used: we need that tool to
produce XML, rather than cryptic plain text.

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

=head1 TODO

=over

=item Dependency computation

trim_directive cuts down the contents of a specified directive by
looking for files in the local prel database that have a given suffix.
This approach is fairly fast, because it just depends on testing
existence of files.  This is perhaps the laziest workable approach; it
ensures only that the article fragmens make sense to the mizar
tools. We should plug in to Josef's code; it requires far more
computation than simply checking the existence of suitable files, but
that is the way we cut things down as far as possible.

=item Emacs

It would be good to move away from emacs, which, I'm sure, makes
things much slower than they need to be.  We are using emacs only in a
limited capacity: extracting regions of text.  We can certainly do
this in perl, and likely much faster.

=item Mizar module

A fair amount of this code deals with just running mizar tools,
checking their return values and existence of a non-empty .err file,
etc.  This kind of thing more naturally belongs in a separate mizar
module rather than here.

=item Unhandled items

=over

=item deffunc

=item defpred

=item reconsider

=item set

=back

=back

=cut

# itemize.pl ends here
