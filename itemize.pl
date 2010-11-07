#!/usr/bin/perl -w

# First sanity check: make sure that MIZFILES is set.  We can't do
# anything it is not set.  Let's not check whether it is a sensible
# value, just that it has some value.
my $mizfiles = $ENV{'MIZFILES'};
unless (defined $mizfiles) {
  die 'The MIZFILES environment variable is unset; nothing more can be done';
}

use Getopt::Euclid; # load this first to set up our command-line parser

use Cwd qw / getcwd /;
use File::Temp qw / tempdir /;
use File::Spec;

######################################################################
### Process the command line
###
###
### We are using Getopt::Euclid; see the documentation section at the
### end of this file to see what command-line options are available.
######################################################################

### --article-source-dir

# First, extract a value
my $article_source_dir = $ARGV{'--article-source-dir'};
unless (defined $article_source_dir) {
  $article_source_dir = "$mizfiles/mml";
}

# Now ensure that this value for is sensible, which in this case
# means: it exists, it's directory, and it's readable.
unless (-e $article_source_dir) {
  die "The given article source directory\n\n  $article_source_dir\n\ndoes not exist!";
}
unless (-d $article_source_dir) {
  die "The given article source directory\n\n$article_source_dir\n\nis not actually a directory!";
}
unless (-r $article_source_dir) {
  die "The given article source directory\n\n$article_source_dir\n\nis not readable!";
}

### --result-dir

# First, extract a value.  In this case, Getopt:Euclid has already
# taken care of this for us, so there's no need to compute a default
# value in case no value was supplied, as was the case for the
# --article-source-dir option.
my $result_dir = $ARGV{'--result-dir'};
unless (defined $result_dir) { # weird: typo on my part or bug in Getopt::Euclid
  die 'No value for the --result-dir option is present in the %ARGV table!';
}

# Ensure that the value is sensible, which in this case means: it
# exists, it's a directory, and it's writable
unless (-e $result_dir) {
  die "The given result directory\n\n  $result_dir\n\ndoes not exist!";
}
unless (-d $result_dir) {
  die "The given result directory\n\n$result_dir\n\nis not actually a directory!";
}
unless (-w $result_dir) {
  die "The given result directory\n\n$result_dir\n\nis not writable!";
}

### --emacs-lisp-dir

# First, extract or assign a value.  As was the case for the
# --result-dir option, a default value has already been specified
# using Getopt::Euclid, so there's no need to compute a default.
my $elisp_dir = $ARGV{'--emacs-lisp-dir'};
unless (defined $elisp_dir) { # weird: typo on my part or bug in Getopt::Euclid
  die 'No value for the --emacs-lisp-dir option is present in the %ARGV table!';
}

# Ensure that the value is sensible, which in this case means: it
# exists, it's a directory, it's readable, and it contains all the
# needed helper elisp code
unless (-e $elisp_dir) {
  die "The given emacs lisp directory\n\n  $elisp_dir\n\ndoes not exist!";
}
unless (-d $elisp_dir) {
  die "The given emacs lisp directory\n\n$elisp_dir\n\nis not actually a directory!";
}
unless (-r $elisp_dir) {
  die "The given emacs lisp directory\n\n$elisp_dir\n\nis not readable!";
}
my @elisp_files = ('reservations.elc');
foreach my $elisp_file (@elisp_files) {
  my $elisp_file_path = File::Spec->catfile ($elisp_dir, $elisp_file);
  unless (-e $elisp_file_path) {
    die "The required emacs lisp file\n\n  $elisp_file\n\ncannot be found under the emacs lisp directory\n\n$elisp_dir";
  }
  unless (-r $elisp_file_path) {
    die "The required emacs lisp file\n\n  $elisp_file\n\nunder the emacs lisp directory\n\n$elisp_dir\n\nis not readable!";
  }
}

### ARTICLE

# First, extract a value of the single required ARTICLE
# argument.
my $article_name = $ARGV{'<ARTICLE>'};
unless (defined $article_name) { # weird: my typo or bug in Getopt::Euclid
  die 'The mandatory ARTICLE argument was somehow omitted!';
}

# Strip the final ".miz", if there is one
my $article_name_len = length $article_name;
if ($article_name =~ /\.miz$/) {
  $article_name = substr $article_name, 0, $article_name_len - 4;
}

my $article_miz = $article_name . '.miz';
my $article_path = File::Spec->catfile ($article_source_dir, $article_name);

# More sanity checks: the mizar file exists and is readable
unless (-e $article_path) {
  die "No file named\n\n  $article_miz\n\nunder the source directory\n\n  $article_source_dir";
}
unless (-r $article_path) {
  die "The file\n\n  $article_miz\n\under the source directory\n\n  $article_source_dir\n\nis not readable";
}

######################################################################
### End command-line processing.
###
### Now we can start doing something.
######################################################################

use XML::LibXML;

my $article_lsp = $article_name . '.lsp';
my $article_xml = $article_name . '.xml';
my $article_xml_absrefs = $article_name . '.xml1';
my $article_idx = $article_name . '.idx';
my $article_tmp = $article_name . '.$-$';
my $article_work_dir = $article_name;
my $article_dict_dir = $article_name . '/' . 'dict';
my $article_prel_dir = $article_name . '/' . 'prel';
my $article_text_dir = $article_name . '/' . 'text';

unless (-e "$article_name.miz") {
  die "Mizar source $article_miz does not exist in the current directory";
}

unless (-e "$article_xml") {
  warn "XML file for article $article_name does not exist in the current directory.  Creating it";
  system ("accom -q -s -l $article_miz > /dev/null 2> /dev/null");
  unless ($? == 0) {
    die ("Something went wrong when calling the accomodator on $article_name: the error was\n\n$!");
  }
  system ("verifier -q -s -l $article_miz > /dev/null 2> /dev/null");
  unless ($? == 0) {
    die ("Something went wrong when calling the verifier on $article_name: the error was\n\n$!");
  }
}

my $absrefs_stylesheet = '/Users/alama/sources/mizar/xsl4mizar/addabsrefs.xsl';
unless (-e "$article_xml_absrefs") {
  warn "Absolute reference version of the the XML file for article $article_name does not exist in the current directory.  Creating it";
  unless (-e $absrefs_stylesheet) {
    die ("No absrefs stylesheet at $absrefs_stylesheet; cannot continue.");
  }
  system ("xsltproc $absrefs_stylesheet $article_xml 2> /dev/null > $article_xml_absrefs");
  unless ($? == 0) {
    die ("Something went wrong when creating the absolute reference XML: the error was\n\n$!");
  }
}

sub make_miz_dir {
  if (-e $article_work_dir) {
    if (-d $article_work_dir) {
      my @workdirs = `find . -type d -name $article_work_dir -empty`;
      if (scalar (@workdirs) == 0) {
	die "Unable to proceed: the working directory for $article_name already exists in this directory but it is not empty; refusing to (potentially) overwrite its contents.";
      } else {
	warn "Warning: the working directory for $article_name already exists in the current directory, but it is empty.  Populating it...";
      }
    } else {
      die ("Unable to proceed: a non-directory with the same name as the working directory for $article_name already exists in the current directory.")
    }
  } else {
    warn "Warning: the working directory for $article_name doesn't yet exist in the current directory; creating it...";
    mkdir ($article_work_dir);
    mkdir ($article_dict_dir);
    mkdir ($article_prel_dir);
    mkdir ($article_text_dir);
  }
}

my @items = ();

make_miz_dir ();

# article environment
my @vocabularies = `/Users/alama/sources/mizar/mwiki/env.pl Vocabularies $article_name`;
chomp (@vocabularies);
@vocabularies = grep (!/^HIDDEN$/, @vocabularies);
my @notations = `/Users/alama/sources/mizar/mwiki/env.pl Notations $article_name`;
chomp (@notations);
@notations = grep (!/^HIDDEN$/, @notations);
my @constructors = `/Users/alama/sources/mizar/mwiki/env.pl Constructors $article_name`;
chomp (@constructors);
@constructors = grep (!/^HIDDEN$/, @constructors);
my @registrations = `/Users/alama/sources/mizar/mwiki/env.pl Registrations $article_name`;
chomp (@registrations);
@registrations = grep (!/^HIDDEN$/, @registrations);
my @requirements = `/Users/alama/sources/mizar/mwiki/env.pl Requirements $article_name`;
chomp (@requirements);
@requirements = grep (!/^HIDDEN$/, @requirements);
my @definitions = `/Users/alama/sources/mizar/mwiki/env.pl Definitions $article_name`;
chomp (@definitions);
@definitions = grep (!/^HIDDEN$/, @definitions);
my @theorems = `/Users/alama/sources/mizar/mwiki/env.pl Theorems $article_name`;
chomp (@theorems);
@theorems = grep (!/^HIDDEN$/, @theorems);
my @schemes = `/Users/alama/sources/mizar/mwiki/env.pl Schemes $article_name`;
chomp (@schemes);
@schemes = grep (!/^HIDDEN$/, @schemes);

my %item_kinds = (); # maps natural numbers to constant strings: 'notation', 'definition', 'registration', 'theorem', 'scheme' etc.

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

  my $item_path = $article_text_dir . '/' . "ITEM$number.miz";
  open (ITEM_MIZ, q{>}, $item_path) or die ("Unable to open an output filehandle at $item_path");
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
    my $earlier_item_kind = $item_kinds{$i-1};
    if ($earlier_item_kind eq 'notation'
	|| $earlier_item_kind eq 'definition'
        || $earlier_item_kind eq 'registration') {
      push (@this_item_notations, "ITEM$i");
    }
  }
  unless (scalar (@this_item_notations) == 0) {
    print ITEM_MIZ ("notations " . join (', ', @this_item_notations) . ";");
    print ITEM_MIZ ("\n");
  }

  # constructors
  my @this_item_constructors = @constructors;
  foreach my $i (1 .. $number - 1) {
    my $earlier_item_kind = $item_kinds{$i-1};
    if ($earlier_item_kind eq 'definition'
	|| $earlier_item_kind eq 'registration'
        || $earlier_item_kind eq 'notation') {
      push (@this_item_constructors, "ITEM$i");
    }
  }
  unless (scalar (@this_item_constructors) == 0) {
    print ITEM_MIZ ("constructors " . join (', ', @this_item_constructors) . ";");
    print ITEM_MIZ ("\n");
  }

  # registrations
  my @this_item_registrations = @registrations;
  foreach my $i (1 .. $number - 1) {
    my $earlier_item_kind = $item_kinds{$i-1};
    if ($earlier_item_kind eq 'registration') {
      push (@this_item_registrations, "ITEM$i");
    }
  }
  unless (scalar (@this_item_registrations) == 0) {
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
    my $earlier_item_kind = $item_kinds{$i-1};
    if ($earlier_item_kind eq 'definition'
        || $earlier_item_kind eq 'notation'
        || $earlier_item_kind eq 'registration') {
      push (@this_item_definitions, "ITEM$i");
    }
  }
  unless (scalar (@this_item_definitions) == 0) {
    print ITEM_MIZ ("definitions " . join (', ', @this_item_definitions) . ";");
    print ITEM_MIZ ("\n");
  }

  # theorems
  my @this_item_theorems = @theorems;
  foreach my $i (1 .. $number - 1) {
    my $earlier_item_kind = $item_kinds{$i-1};
    # DEBUG
    # warn ("earlier item $i is type $earlier_item_kind");
    if ($earlier_item_kind eq 'theorem'
	|| $earlier_item_kind eq 'definition'
        || $earlier_item_kind eq 'notation') {
      push (@this_item_theorems, "ITEM$i");
    }
  }
  unless (scalar (@this_item_theorems) == 0) {
    print ITEM_MIZ ("theorems " . join (', ', @this_item_theorems) . ";");
    print ITEM_MIZ ("\n");
  }

  # schemes
  my @this_item_schemes = @schemes;
  foreach my $i (1 .. $number - 1) {
    my $earlier_item_kind = $item_kinds{$i-1};
    if ($earlier_item_kind eq 'scheme') {
      push (@this_item_schemes, "ITEM$i");
    }
  }
  unless (scalar (@this_item_schemes) == 0) {
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
  my @output = `emacs23 --quick --batch --load reservations.elc --visit $article_miz --funcall find-reservations`;
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

sub tokens {
  unless (-e $article_lsp) {
    die ("$article.lsp doesn't exist; unable to proceed");
  }
  my @tokens = ();
  open (LSP, q{<}, $article_lsp)
    or die ("Unable to open $article.lsp for reading; unable to proceed");
  my $token;
  while (defined ($token = <LSP>)) {
    chomp ($token);
    push (@tokens, $token);
  }
  close (LSP)
    or die ("Unable to close input filehandle for $article.lsp");
  return (\@tokens);
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

sub split_reservations {
  # ugh -- the JA tool screws up line numbering when comments are present!  we need to strip comments first.
  my $sed_command = "sed -e 's/\\ *::.*//' < $article_miz > $article_miz-no-comments";
  # DEBUG
  warn ("about to execute this sed command: $sed_command");
  system ($sed_command);
  system ('mv', "$article_miz-no-comments", "$article_miz");
  system ("accom -q -s -l $article_miz > /dev/null 2> /dev/null");
  unless ($? == 0) {
    die ("Something went wrong when calling the accomodator on $article_name: the error was\n\n$!");
  }
  system ("JA $article_miz > /dev/null 2> /dev/null");
  unless ($? == 0) {
    die ("Something went wrong when calling the JA tool on $article_name: the error was\n\n$!");
  }
  system ("edtfile $article_name > /dev/null 2> /dev/null");
  unless ($? == 0) {
    die ("Something went wrong when calling edtfile on $article_name: the error was\n\n$!");
  }
  system ('mv', $article_tmp, $article_miz);
  unless ($? == 0) {
    die ("Something went wrong when overwriting the original .miz file by one whose reservations are split up by the JA tool: the error was\n\n$!");
  }
  # Done.  We shouldn't need to call the accomodator and the verifier
  # on the new .miz, right, since it's "the same" as the old,
  # non-split one?  Right?  (This is not the case for the JA1 tool,
  # since that one will have a slightly different XML representation:
  # no Reservation element will have more than one Ident child.)

  # We are NOT done: JA might change line numbering:
  #
  # reserve A,B,C for Ordinal,
  # X,X1,Y,Y1,Z,a,b,b1,b2,x,y,z for set,
  # R for Relation
  #  ,
  # f,g,h for Function,
  # k,m,n for natural number;
  #
  # gets sent by JA to
  #
  # reserve A,B,C for  Ordinal;
  # reserve X,X1,Y,Y1,Z,a,b,b1,b2,x,y,z for  set;
  # reserve R for  Relation;
  # reserve f,g,h for  Function;
  # reserve k,m,n for  natural number;
  #
  # The first bunch of reservations spans 6 lines, but the new one spans 5!
  system ("accom -q -s -l $article_miz > /dev/null 2> /dev/null");
  unless ($? == 0) {
    die ("Something went wrong when calling the accomodator on $article_name: the error was\n\n$!");
  }
  # DEBUG
  warn "Verifying again (thanks, JA...)";
  system ("verifier -q -s -l $article_miz > /dev/null 2> /dev/null");
  unless ($? == 0) {
    die ("Something went wrong when calling the verifier on $article_name: the error was\n\n$!");
  }
  # DEBUG
  warn "Regenerating the absolute reference XML (thanks, JA...)";
  system ("xsltproc $absrefs_stylesheet $article_xml 2> /dev/null > $article_xml_absrefs");
  unless ($? == 0) {
    die ("Something went wrong when creating the absolute reference XML: the error was\n\n$!");
  }
}

# sub split_reservations {
#   my $tokens_ref = tokens ();
#   my @tokens = @{$tokens_ref};
#   my @reservations = ();
#   my $reservation = "";
#   my $scanning_identifiers = 0;
#   my $scanning_reservation_block = 0;
#   for (my $i = 0, $i++, ) {
#     my $token = $tokens[$i];
#     if ($token eq 'reserve') {
#       $scanning_identifiers = 1;
#       $scanning_reservation_block = 1;
#     } elsif ($scanning_identifiers) {
#       $reservation .= $token;
#     } elsif ($token eq 'for') {
#       $scanning_identifiers = 0;
#       $reservations .= $token;
#     } elsif ($scanning_reservation_block) {
#       my $next = $tokens[$i + 1];
#       $reservations .= $next;
#       if ($next eq ';') {
# 	push (@reservations, $reservation);
# 	$reservation = '';
# 	$scanning_reservation_block = 0;
#       } elsif ($next eq 'of' or $next eq 'over') {
# 	my $after_next = $tokens[$i + 2];
# 	until ($after_next eq ';' or $after_next eq 'for') {
# 	  $reservation .= $token;
# 	  $i++;
# 	  $token = $tokens[$i];
# 	  $next = $tokens[$i + 1];
# 	  $after_next = $tokens[$i + 2];
# 	}
# 	if ($after_next eq ';') {
# 	  $scanning_reservation_block = 0;
# 	}
#       }
#     }
#   }
#   return (\@reservations);
# }

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
  my @output = `emacs23 --quick --batch --load reservations.elc --visit $article_miz --eval '(scheme-before-position $line $col)'`;
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
  my @output = `emacs23 --quick --batch --load reservations.elc --visit $article_miz --eval '(theorem-before-position $line $col)'`;
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
  my @output = `emacs23 --quick --batch --load reservations.elc --visit $article_miz --eval '(definition-before-position $line $col)'`;
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
    $emacs_command = "emacs23 --quick --batch --load reservations.elc --visit $article_miz --eval \"(extract-region-replacing-schemes-and-definitions-and-theorems '$item_kind \\\"$label\\\" $bl $bc $el $ec)\"";
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

    $emacs_command = "emacs23 --quick --batch --load reservations.elc --visit $article_miz --eval \"(extract-region-replacing-schemes-and-definitions-and-theorems '$item_kind \\\"$label\\\" $bl $bc $el $ec $instructions)\"";
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
split_reservations ();
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
  my @output = `emacs23 --quick --batch --load reservations.elc --visit $article_miz --eval '(toplevel-unexported-theorem-before-position-with-label $end_line $end_col \"$label\")'`;
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
  my @output = `emacs23 --quick --batch --load reservations.elc --visit $article_miz --funcall (position-of-theorem-keyword-before-position)`;
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

    # register this in the item kind table
    if ($node_name eq 'DefinitionBlock') {
      $item_kinds{$i-1} = 'definition';
    } elsif ($node_name eq 'SchemeBlock') {
      $item_kinds{$i-1} = 'scheme';
    } elsif ($node_name eq 'RegistrationBlock') {
      $item_kinds{$i-1} = 'registration';
    } elsif ($node_name eq 'NotationBlock') {
      $item_kinds{$i-1} = 'notation';
    } elsif ($node_name eq 'JustifiedTheorem') {
      $item_kinds{$i-1} = 'theorem';
    } elsif ($node_name eq 'Proposition') {
      $item_kinds{$i-1} = 'theorem';
    } elsif ($node_name eq 'DefTheorem') {
      # DEBUG
      warn ('We just encountered a DefTheorem node');
      $item_kinds{$i-1} = 'theorem';
    } else {
      die ("Unable to register node $i: unknown type $node_name");
    }

    # DEBUG
    warn ("This is item $i, and we just set its type to " . $item_kinds{$i-1} . "...so there");

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

# separate_theorems ();


# my $reservations_ref = split_reservations ();
# my @reservations = @{$reservations_ref};
# foreach my $reservation (@reservations) {
#   print "$reservation\n";
# }

=head1 NAME

itemize – Decompose a mizar article into its constituent parts

=head1 USAGE

  itemize.pl --article-source-dir=<DIRECTORY>
             --result-dir=<DIRECTORY>
             --emacs-lisp-dir=<DIRECTORY>
             <ARTICLE>

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

ARTICLE must be at most 1 but at most 32 alphanumeric characters long,
excluding an optional ".miz" file extension.

=for Euclid:
     ARTICLE.type: /^[A-Za-z]{1,32}+(\.miz)?$/
     ARTICLE.type.error:   Article name must be at most 32 alphanumeric characters long (but it may end with the ".miz" suffix)

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

Make a local mizar database for ARTICLE in RESULT-DIRECTORY.  The
database will itself be a subdirecory of RESULT-DIRECTORY called by
the same name as ARTICLE; the database itself will contain
subdirectories 'prel' and 'text'.

RESULT-DIRECTORY, if unset, defaults to the current directory.  If
set, it should be a path; it can be either an absolute path (beginning
with a forward slash '/') or a relative path (i.e., anything that is
not an absolute path).  In either case, it is up to the user to ensure
that, if RESULT-DIRECTORY is set, that the directory exists and is
writable.

=for Euclid:
     RESULT-DIRECTORY.default: '.'

=item --emacs-lisp-dir=<ELISP-DIR>

The directory in which to look for the Emacs Lisp code that this
program uses.  The default is to use the current directory.

=for Euclid:
     ELISP-DIR.default: '.'

=item --version

=item --usage

=item --help

=item --man

=back

Print the usual program information.

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
