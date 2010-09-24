#!/usr/bin/perl -w

sub usage {
  print <<'END_USAGE';
Usage: itemize.pl ARTICLE

ARTICLE should be the name of an article that exists in the current
directory.  If it ends with ".miz", then the part of the article
before the ".miz" will be treated as the name of the article.

A directory called ARTICLE will be created in the current directory.
Upon termination, the directory ARTICLE will be a mizar "working
directory" containing subdirectories "dict", "prel", and "text".
Inside the "text" subdirectory there will be as many new mizar
articles as there are items in ARTICLE.  The "dict" subdirectory will
likewise contain as vocabulary files as there are items in ARTICLE.
The "prel" subdirectory will contain the results of calling miz2prel
on each of the standalone articles.

END_USAGE
}

use XML::LibXML;

my $article_name = $ARGV[0];
my $article_miz = $article_name . '.miz';
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
  my @symbols = $doc->findnodes ('/Symbol');
  foreach my $symbol (@symbols) {
    my $vid = $symbol->findvalue ('@nr');
    my $name = $symbol->findvalue ('@name');
    $vid_table{$vid} = $name;
  }
}

sub split_reservations {
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
#   # We could load this information at once, but to be safe let's use the evl.
#   my @vocabularies = `env.pl Vocabularies $article_base`;
#   my @notations = `env.pl Notations $article_base`;
#   my @constructors = `env.pl Constructors $article_base`;
#   my @registrations = `env.pl Registrations $article_base`;
#   my @requirements = `env.pl Requirements $article_base`;
#   my @definitions = `env.pl Definitions $article_base`;
#   my @theorems = `env.pl Theorems $article_base`;
#   my @schemes = `env.pl Schemes $article_base`;
# }

sub load_environment {
  my @output = `emacs23 --quick --batch --load reservations.elc --visit $article_miz --funcall article-environment`;
  unless ($? == 0) {
    die ("Weird: emacs didn't exit cleanly: $!");
  }
  # can't we just turn this list of strings into a single string,
  # using a builtin command?  this looks so primitive
  my $environment = '';		# empty string
  foreach my $line (@output) {
    chomp ($line);
    $environment .= "$line\n";
  }
  return ($environment);
}

sub print_reservation_table {
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
  foreach my $key (keys (%reservation_table)) {
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
  foreach $out_line (@output) {
    chomp ($out_line);
    $scheme .= "$out_line\n";
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

sub extract_article_region {
  my $bl = shift;
  my $bc = shift;
  my $el = shift;
  my $ec = shift;
  my $region = ''; # empty string
  my @output = `emacs23 --quick --batch --load reservations.elc --visit $article_miz --eval '(extract-region $bl $bc $el $ec)'`;
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
my $environment = load_environment ();
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

sub pretext_from_item_type_and_beginning {
  my $item_type = shift;
  my $begin_line = shift;
  my $begin_col = shift;
  my $pretext;
  if ($item_type eq 'JustifiedTheorem') {
    $pretext = theorem_before_position ($begin_line, $begin_col);
  } elsif ($item_type eq 'SchemeBlock') {
    $pretext = scheme_before_position ($begin_line, $begin_col);
  } elsif ($item_type eq 'NotationBlock') {
    $pretext = "notation\n";
  } elsif ($item_type eq 'DefinitionBlock') {
    $pretext = "definition\n";
  } elsif ($item_type eq 'RegistrationBlock') {
    $pretext = "registration\n";
  } elsif ($item_type eq 'Proposition') {
    $pretext = ":: Don't know how to handle diffuse lemmas\n";
  } else {
    $pretext = '';
  }
  return ($pretext);
}

sub itemize {
  my $doc = miz_xml ();
  @tpnodes = $doc->findnodes ('//JustifiedTheorem | //Proposition[(name(..)="Article")] | //DefinitionBlock | //SchemeBlock | //RegistrationBlock | //NotationBlock');
  my $i;
  foreach my $i (0 .. $#tpnodes) {
    my $node = $tpnodes[$i];
    my $node_name = $node->nodeName;

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

    # now find the end
    my ($end_line, $end_col);
    my $last_endposition_child;

    # we need to look at its proof
    if ($node_name eq 'Proposition') {
      my $next = $node->nextNonBlankSibling ();
      unless (defined ($next)) {
	die ("Weird: node $i, a Proposition, is not followed by a sibling!");
      }
      my $next_name = $next->nodeName ();
      unless ($next_name eq 'Proof') {
	die ("Weird: the next sibling of node $i, a Proposition, is not a Proof element! It is a $next_name element, somehow");
      }
      ($last_endposition_child)
	= $next->findnodes ('EndPosition[position()=last()]');
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
	  die ("Node $i, a JustifiedTheorem, is immediately justified, but no statements are mentioned after the by/from keyword!");
	}
      } else {
	die ("Node $i, a JustifiedTheorem, lacks a Proof, nor is it immediately justified by a By or From statement");
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
    if ($node_name eq 'JustifiedTheorem') {
      $begin_col = $begin_col + 3;
    }

    # extract appropriate reservations
    # my @reservations = @{reservations_before_line ($begin_line)};

    # compute any lost "pretext" information
    my $pretext
      = pretext_from_item_type_and_beginning ($node_name, $begin_line, $begin_col);

    my $text = extract_article_region ($begin_line, $begin_col, $end_line, $end_col);
    chomp ($text);
    print ("Item $i: $node_name: ($begin_line,$begin_col)-($end_line,$end_col)\n");
    print ("======================================================================\n");
    print ("$pretext");
    print ("$text");
    print (";\n");
    print ("======================================================================\n");
  }
}

itemize ();

# separate_theorems ();


# my $reservations_ref = split_reservations ();
# my @reservations = @{$reservations_ref};
# foreach my $reservation (@reservations) {
#   print "$reservation\n";
# }
