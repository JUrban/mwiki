#!/usr/bin/perl -w

# stolen from mizp.pl

# TODO

use XML::LibXML;

my $article_name = $ARGV[0];
my $article_miz = $article_name . '.miz';
my $article_xml = $article_name . '.xml1';
my $article_work_dir = $article_name . '-items';

unless (-e "$article_name.miz") {
  die "Mizar source $article_miz does not exist in the current directory";
}

unless (-e "$article_xml") {
  die "XML file for article $article_name does not exist in the current directory.";
}

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
  return ($parser->parse_file($article_xml));
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

sub prepare_work_dirs {
  my $theorems_dir = $article_work_dir . '/' . 'theorems';
  my $schemes_dir = $article_work_dir . '/' . 'schemes';
  my $definitions_dir = $article_work_dir . '/' . 'definitions';
  mkdir ($theorems_dir);
  mkdir ($definitions_dir);
  return;
}

sub load_environment {
  my @output = `emacs23 --quick --batch --load reservations.elc --visit $article_miz --funcall article-environment`;
  unless ($? == 0) {
    die ("Weird: emacs didn't exit cleanly: $!");
  }
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

prepare_work_dirs ();
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

sub scan_vids {
  my $doc = miz_xml ();
  # my @tpnodes = ();
  # my @theorem_nodes = $doc->findnodes ('//JustifiedTheorem');
  # push (@tpnodes, @theorem_nodes);
  # my @lemma_nodes = $doc->findnodes ('//Proposition[(name(..)="Article")]');
  # push (@tpnodes, @lemma_nodes);
  # my @definition_block_nodes = $doc->findnodes ('//DefinitionBlock');
  # push (@tpnodes, @definition_block_nodes);
  # my @scheme_block_nodes = $doc->findnodes ('//SchemeBlock');
  # push (@tpnodes, @scheme_block_nodes);
  @tpnodes = $doc->findnodes ('//JustifiedTheorem | //Proposition[(name(..)="Article")] | //DefinitionBlock | //SchemeBlock');
  my $definition_blocks = 0;
  my $diffuse_lemmas = 0;
  my $justified_theorems = 0;
  my $scheme_blocks = 0;
  foreach my $node (@tpnodes) {
    my $node_name = $node->nodeName;
    if ($node_name eq "JustifiedTheorem" || $node_name eq "Proposition") {
      my $proposition_node;
      if ($node_name eq "Proposition") {
	$proposition_node = $node;
	warn ("a diffuse proposition!");
	$diffuse_lemmas++;
      } else {
	($proposition_node) = $node->findnodes ('Proposition');
	$justified_theorems++;
      }
      if (defined ($proposition_node)) {
	my $vid = $proposition_node->findvalue ('@vid');
	if (defined ($vid)) {
	  if ($vid eq '') {
	    if ($node_name eq 'JustifiedTheorem') {
	      warn ("weird: justifiedtheorem $justified_theorems has an empty value for its VID attribute\n");
	    } else {
	      warn ("weird: diffuse lemma $diffuse_lemmas has an empty value for its VID attribute\n");
	    }
	  } else {
	    if ($node_name eq 'JustifiedTheorem') {
	      warn ("setting vid of theorem $justified_theorems to $vid\n");
	      $vid_to_theorem_num{$vid} = $justified_theorems;
	      $theorem_num_to_vid{$justified_theorems} = $vid;
	    } else {
	      warn ("setting vid of diffuse lemma $diffuse_lemmas to $vid");
	      $vid_to_diffuse_lemma_num{$vid} = $diffuse_lemmas;
	      $diffuse_lemmas_to_vid{$diffuse_lemmas} = $vid;
	    }
	  }
	} else {
	  warn ("weird: the Proposition node of theorem $i lacks a value for its VID attribute\n");
	}
      } else {
	warn ("weird: theorem $i is a JustifiedTheorem, but it lacks a Proposition child element\n");
      }
    } elsif ($node_name eq 'DefinitionBlock') {
      warn ("Don't know how to deal with DefinitionBlocks yet...\n");
      $definition_blocks++;
    } elsif ($node_name eq 'SchemeBlock') {
      warn ("Don't know how to deal with SchemeBlocks yet...\n");
      $scheme_blocks++;
    }
  }
}

sub separate_theorems {
  my $doc = miz_xml ();
  # my @tpnodes = ();
  # my @justified_theorem_nodes = $doc->findnodes('//JustifiedTheorem');
  # my @lemma_nodes = $doc->findnodes ('//Proposition[(name(..)="Article")]');
  # push (@tpnodes, @justified_theorem_nodes);
  # push (@tpnodes, @lemma_nodes);
  @tpnodes = $doc->findnodes ('//JustifiedTheorem | //Proposition[(name(..)="Article")] | //DefinitionBlock | //SchemeBlock');
  my $definition_blocks = 0;
  my $diffuse_lemmas = 0;
  my $justified_theorems = 0;
  my $scheme_blocks = 0;
  foreach my $node (@tpnodes) {
    my $node_name = $node->nodeName;

    # counting
    if ($node_name eq 'JustifiedTheorem') {
      $justified_theorems++;
    } elsif ($node_name eq 'Proposition') {
      $diffuse_lemmas++;
    } elsif ($node_name eq 'DefinitionBlock') {
      $definition_blocks++;
    } else {
      $scheme_blocks++;
    }

    if ($node->exists ('SkippedProof')) {
      warn ("Skipping over a cancelled proof...\n");
    } else {
      # first, gather the references (bys and froms)
      my %local_refs = ();
      my @by_nodes = $node->findnodes ('.//By'); # note xpath magic './/'
      my @from_nodes = $node->findnodes ('.//From'); # note xpath magic './/'
      my @by_refs = article_local_references_from_nodes (\@by_nodes);
      my @from_refs = article_local_references_from_nodes (\@from_nodes);

      # DEBUG
      foreach my $ref (@by_refs) {
	if ($node_name eq 'JustifiedTheorem') {
	  warn ("by reference in the proof of justifiedtheorem $justified_theorems to thing $ref\n");
	} elsif ($node_name eq 'Proposition') {
	  warn ("diffuse lemma $diffuse_lemmas refers to thing $ref\n");
	} elsif ($node_name eq 'DefinitionBlock') {
	  warn ("definition block $definition_blocks refers to thing $ref\n");
	} else {
	  warn ("scheme $scheme_blocks refers to thing $ref");
	}
      }
      # DEBUG
      foreach my $ref (@by_refs) {
	if ($node_name eq 'JustifiedTheorem') {
	  warn ("by reference in the proof of justifiedtheorem $justified_theorems to thing $ref\n");
	} elsif ($node_name eq 'Proposition') {
	  warn ("diffuse lemma $diffuse_lemmas refers to thing $ref\n");
	} elsif ($node_name eq 'DefinitionBlock') {
	  warn ("definition block $definition_blocks refers to thing $ref\n");
	} else {
	  warn ("scheme $scheme_blocks refers to thing $ref");
	}
      }  

      if ($node->nodeName eq "DefinitionBlock") {
	warn ("Ignoring DefinitionBlock..");
      } elsif ($node_name eq 'SchemeBlock') {
	warn ("Ignoring SchemeBlock...\n");
      } else { # we handle only JustifiedTheorems and toplevel Propositions now
	my ($proof_node) = $node->findnodes ('Proof');
	if (defined ($proof_node)) {
	  my ($endpos) = $proof_node->findnodes('EndPosition[position()=last()]');
	  my ($bl,$bc,$el,$ec) = ($proof_node->findvalue('@line'),
				  $proof_node->findvalue('@col'),
				  $endpos->findvalue('@line'),
				  $endpos->findvalue('@col'));
	  my $res = reservations_before_line ($el);
	  my @reservations_in_force = @{$res};
	  my $theorem = theorem_before_position ($bl, $bc);
	  my $theorem_dir
	    = $article_work_dir . '/' . 'theorems' . '/' . "$i";
	  my $theorem_miz = $theorem_dir . "/" . "theorem$i.miz";
	  mkdir ($theorem_dir);
	  open (THEOREM_MIZ, q{>}, $theorem_miz)
	    or die ("Couldn't open an output filehandle to $theorem_miz");
	  print THEOREM_MIZ ("environ\n");
	  print THEOREM_MIZ ("$environment\n");
	  print THEOREM_MIZ ("begin\n");
	  foreach my $reservation (reverse @reservations_in_force) {
	    print THEOREM_MIZ ("reserve $reservation\n");
	  }
	  print THEOREM_MIZ ("$theorem");
	  # now print the proof
	  my $miz_line = $mizfile_lines[$bl-1];
	  if ($bl == $el) {	# weird: entire proof is on one line
	    print THEOREM_MIZ (substr ($miz_line, $bc, $ec-$bc));
	  } else { # more typical: the proof does not begin and end on the same line
	    my $first_line_remainder = substr($miz_line, $bc);
	    print THEOREM_MIZ ($first_line_remainder);
	    for (my $line = $bl; $line < $el; $line++) {
	      print THEOREM_MIZ ($mizfile_lines[$line]);
	      print THEOREM_MIZ ("\n");
	    }
	    print THEOREM_MIZ (substr ($mizfile_lines[$el],0,$ec));
	  }
	  close (THEOREM_MIZ)
	    or die ("Unable to close the output filehandle for $theorem_miz");
	} else {
	  warn ("this node (for theorem $i) does not have a proof; looking for By\n");
	  my ($by_node) = $node->findnodes('By');
	  if (defined ($by_node)) {
	    my ($by_line,$by_column) = ($by_node->findvalue ('@line'),
					$by_node->findvalue ('@col'));
	    warn ("by_line = $by_line and by_column = $by_column\n");
	    my ($first_ref_node) = $by_node->findnodes ('Ref');
	    my ($last_ref_node) = $by_node->findnodes ('Ref[position()=last()]');
	    my ($first_ref_line,$first_ref_column)
	      = ($first_ref_node->findvalue ('@line'),
		 $first_ref_node->findvalue ('@col'));
	    my ($last_ref_line,$last_ref_column)
	      = ($last_ref_node->findvalue ('@line'),
		 $last_ref_node->findvalue ('@col'));
	    my $res = reservations_before_line ($last_ref_line);
	    my @reservations_in_force = @{$res};
	    my $theorem = theorem_before_position ($by_line, $by_column - 3);
	    chomp ($theorem);
	    my $theorem_by_refs = extract_article_region ($by_line,
							  $by_column + 1,
							  $last_ref_line,
							  $last_ref_column);
	    chomp ($theorem_by_refs);
	    my $theorem_dir = $article_work_dir . '/' . 'theorems' . '/' . "$i";
	    my $theorem_miz = $theorem_dir . "/" . "theorem$i.miz";
	    mkdir ($theorem_dir);
	    open (THEOREM_MIZ, q{>}, $theorem_miz)
	      or die ("Couldn't open an output filehandle to $theorem_miz");
	    print THEOREM_MIZ ("environ\n");
	    print THEOREM_MIZ ("$environment\n");
	    print THEOREM_MIZ ("begin\n");
	    foreach my $reservation (reverse @reservations_in_force) {
	      print THEOREM_MIZ ("reserve $reservation\n");
	    }
	    print THEOREM_MIZ ("$theorem");
	    print THEOREM_MIZ " by ";
	    print THEOREM_MIZ ("$theorem_by_refs;");
	    close (THEOREM_MIZ)
	      or die ("Unable to close the output filehandle for $theorem_miz");
	  }
	}
      }
    }
  }
  return;
}

scan_vids ();

separate_theorems ();
