#!/usr/bin/perl -w

# Using the env2txt XSL transformation sheet combined with the output
# of envget, compute the list of all dependenceis for the MML.

use strict;
use warnings;
use File::Temp qw/ tempfile tempdir /;
use Cwd;
use Carp qw/ croak /;

# Global variables
my $mizfiles = $ENV{"MIZFILES"};
my $mml_dir = $mizfiles . "/" . "mml";
my $mml_lar_path = $mizfiles . "/" . "mml.lar";
my $envget = "/Users/alama/sources/mizar/mizar-source-git/envget";
my $evl2txt = "/Users/alama/sources/mizar/xsl4mizar/evl2txt.xsl";

# Compute the articles mentioned in mml.lar

my @mml_lar = ();
sub read_mml_lar {
  my $mml_lar_fh;
  open ($mml_lar_fh, q{<}, $mml_lar_path)
    or croak ("Unable to open the mml.lar at $mml_lar_path!");
  while (<$mml_lar_fh>) {
    chomp ();
    push (@mml_lar, $_);
  }
  close ($mml_lar_fh) 
    or croak ("Unable to close the filehandle created when scanning mml.lar!");
  @mml_lar = reverse (@mml_lar);
  push (@mml_lar, "tarski");
  return (\@mml_lar);
}

my $tempdir;
my $currdir = getcwd ();
sub copy_mml_lar {
  # Copy the articles to a temporary directory
  $tempdir = tempdir (CLEANUP => 0) # don't clean up the temporary
                                    # directory -- we may want to look
                                    # at the damage done there after
                                    # this script exits
  or croak ("Unable to create a temporary directory!");

  # Copy the MML to the temporary directory, giving each article its own
  # directory.
  my ($article_temp_dir, $article_temp_filename, $article_mml_filename);
  foreach my $article (@mml_lar) {
    $article_temp_dir = "$tempdir/$article";
    $article_mml_filename = $mml_dir . "/" . $article . ".miz";
    $article_temp_filename = $article_temp_dir . "/" . $article . ".miz";
    system ("mkdir", $article_temp_dir) == 0
      or croak ("Unable to make a subdirecory for $article in the temporary directory $tempdir!");
    system ("cp", $article_mml_filename, $article_temp_filename);
  }
  return ($tempdir);
}

my %vocabularies_deps;
my %notations_deps;
my %constructors_deps;
my %registrations_deps;
my %requirements_deps;
my %definitions_deps;
my %theorems_deps;
my %schemes_deps;
my %vocabularies_converse_deps;
my %notations_converse_deps;
my %constructors_converse_deps;
my %registrations_converse_deps;
my %requirements_converse_deps;
my %definitions_converse_deps;
my %theorems_converse_deps;
my %schemes_converse_deps;

sub initialize_all_article_dependencies {
  foreach my $article (@mml_lar) {
    my @article_deps = @{article_dependencies ($article)};
    my @article_vocabularies = @{$article_deps[0]};
    my @article_notations = @{$article_deps[1]};
    my @article_constructors = @{$article_deps[2]};
    my @article_registrations = @{$article_deps[3]};
    my @article_requirements = @{$article_deps[4]};
    my @article_definitions = @{$article_deps[5]};
    my @article_theorems = @{$article_deps[6]};
    my @article_schemes = @{$article_deps[7]};
    $vocabularies_deps{$article} = \@article_vocabularies;
    $notations_deps{$article} = \@article_notations;
    $constructors_deps{$article} = \@article_constructors;
    $registrations_deps{$article} = \@article_registrations;
    $requirements_deps{$article} = \@article_requirements;
    $definitions_deps{$article} = \@article_definitions;
    $theorems_deps{$article} = \@article_theorems;
    $schemes_deps{$article} = \@article_schemes;
  }
}

sub article_envget {
  my $article = shift ();
  my $article_temp_dir = $tempdir . "/" . $article;
  # Call envget and use the evl2txt XSLT sheet to get the dependenceis
  # for each article.  Die immediately if anything goes wrong.
  my $envget_exit_status;
  my ($article_evl, $article_err, $article_dep);
  chdir ($article_temp_dir);
  system ($envget, "$article.miz");
  $envget_exit_status = ($? >> 8);
  unless ($envget_exit_status == 0) {
    # It is not enough to simply note articles on which envget dies or
    # produces errors, and continue processing.  We must die here
    # because if some article generates errors, then we cannot rely on
    # the data computed from the articles on which envget does not
    # die; the generated dependency graph would simply not represent
    # the MML, and it would be impossible to compute the missing data.
    croak ("envget died while processing $article");
  }
  $article_err = $article_temp_dir . "/" . $article. ".err";
  $article_evl = $article_temp_dir . "/" . $article. ".evl";
  if (-s $article_err > 0) {
    # As above: if errors were generated, then we can't trust the data
    # generated by envget.
    croak ("envget generated errors when given $article; unable to proceed");
  }

}

sub article_evl2txt {
  my $article = shift ();
  article_envget ($article);
  my $article_evl = $article . ".evl";
  my $article_dep = $article . ".dep";
  my $article_temp_dir = $tempdir . "/" . $article;
  my $xsltproc_exit_status;
  chdir ($article_temp_dir);
  system ("xsltproc", "--output", $article_dep, $evl2txt, $article_evl);
  $xsltproc_exit_status = ($? >> 8);
  unless ($xsltproc_exit_status == 0) {
    # Ditto.
    croak ("xsltproc did not exit cleanly when given $article_evl");
  }
}

sub article_dependencies {
  my $article = shift ();
  article_evl2txt ($article);
  # Parse the output from xsltproc generated by applying the evl2txt sheet.
  my ($dep_line, $semi_dep_line_field, $dep_line_field);
  my @dep_line_fields = ();
  my @article_vocabularies = ();
  my @article_notations = ();
  my @article_constructors = ();
  my @article_registrations = ();
  my @article_requirements = ();
  my @article_definitions = ();
  my @article_theorems = ();
  my @article_schemes = ();
  my @article_deps;
  my $article_temp_dir = $tempdir . "/" . $article;
  my $article_dep = $article . ".dep";
  chdir ($article_temp_dir);
  my $article_dep_fh;
  open ($article_dep_fh, q{<}, $article_dep)
    or croak ("Unable to open article dependency file $article_dep under $article_temp_dir!");
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

    if ($first_element eq "vocabularies") {
      @article_vocabularies = @dep_line_entries;
    }
    
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

  @article_deps = (\@article_vocabularies,
		   \@article_notations,
		   \@article_constructors,
		   \@article_registrations,
		   \@article_requirements,
		   \@article_definitions,
		   \@article_theorems,
		   \@article_schemes);
  return (\@article_deps);
}

sub converse {
  # Naive quadratic implementation.  Tons of intermediate junk
  # generated along the way.  Does perl have a garbage collector?
  my $arg = shift ();
  my %relation = %{$arg};
  my %converse = ();
  my $elt;
  my $range_elt;
  foreach my $elt (keys (%relation)) {
    my $value = $relation{$elt};
    my @range = @{$value};
    foreach my $range_elt (@range) {
      my @domain;
      my $range_value = $converse{$range_elt};
      if (defined ($range_value)) {
	@domain = @{$range_value};
      } else {
	@domain = ();
      }
      push (@domain, $elt);
      $converse{$range_elt} = \@domain;
    }
  }
  return (\%converse);
}

sub compute_converses {
  my $vocaularies_converse = converse (\%vocabularies_deps);
  %vocabularies_converse_deps = %{$vocaularies_converse};
  my $notations_converse = converse (\%notations_deps);
  %notations_converse_deps = %{$notations_converse};
  my $constructors_converse = converse (\%constructors_deps);
  %constructors_converse_deps = %{$constructors_converse};
  my $registrations_converse = converse (\%registrations_deps);
  %registrations_converse_deps = %{$registrations_converse};
  my $requirements_converse = converse (\%requirements_deps);
  %requirements_converse_deps = %{$requirements_converse};
  my $definitions_converse = converse (\%definitions_deps);
  %definitions_converse_deps = %{$definitions_converse};
  my $theorems_converse = converse (\%theorems_deps);
  %theorems_converse_deps = %{$theorems_converse};
  my $schemes_converse = converse (\%schemes_deps);
  %schemes_converse_deps = %{$schemes_converse};
}

sub print_table {
  my $arg = shift ();
  my %table = %{$arg};
  foreach my $key (keys (%table)) {
    my $value = $table{$key};
    my @values = @{$value};
    my $num_values = scalar (@values);
    print ("$key: ");
    for (my $i = 0; $i < $num_values; $i++) {
      print $values[$i];
      unless ($i == $num_values - 1) {
	print (" ");
      }
    }
    print ("\n");
  }
}

sub print_relations {
  print ("The vocabularies relation:\n");
  print_table (\%vocabularies_deps);
  print ("The notations relation:\n");
  print_table (\%notations_deps);
  print ("The constructors relation:\n");
  print_table (\%constructors_deps);
  print ("The registrations relation:\n");
  print_table (\%registrations_deps);
  print ("The requirements relation:\n");
  print_table (\%requirements_deps);
  print ("The definitions relation:\n");
  print_table (\%definitions_deps);
  print ("The theorems relation:\n");
  print_table (\%theorems_deps);
  print ("The schemes relation:\n");
  print_table (\%schemes_deps);
}

sub print_converses {
  print ("Converse of the vocabularies relation:\n");
  print_table (\%vocabularies_converse_deps);
  print ("Converse of the notations relation:\n");
  print_table (\%notations_converse_deps);
  print ("Converse of the constructors relation:\n");
  print_table (\%constructors_converse_deps);
  print ("Converse of the registrations relation:\n");
  print_table (\%registrations_converse_deps);
  print ("Converse of the requirements relation:\n");
  print_table (\%requirements_converse_deps);
  print ("Converse of the definitions relation:\n");
  print_table (\%definitions_converse_deps);
  print ("Converse of the theorems relation:\n");
  print_table (\%theorems_converse_deps);
  print ("Converse of the schemes relation:\n");
  print_table (\%schemes_converse_deps);
}

read_mml_lar ();
copy_mml_lar ();
initialize_all_article_dependencies ();
print_relations ();
compute_converses ();
print_converses ();
