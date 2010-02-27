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

my ($tempdir, $currdir);
sub copy_mml_lar {
  # Copy the articles to a temporary directory
  $tempdir = tempdir (CLEANUP => 0) # don't clean up the temporary
                                       # directory -- we may want to
                                       # look at the damage done there
                                       # after this script exits
  or croak ("Unable to create a temporary directory!");
  $currdir = getcwd ();

  # Copy the MML to the temporary directory, giving each article its own
  # directory.
  my ($article_temp_dir, $article_temp_filename, $article_mml_filename);
  foreach my $article (@mml_lar) {
    $article_temp_dir = "$tempdir/$article";
    $article_mml_filename = $mizfiles . "/" . $article . ".miz";
    $article_temp_filename = $article_temp_dir . "/" . $article . ".miz";
    system ("mkdir", $article_temp_dir)
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
my %vocaularies_converse_deps;
my %notations_converse_deps;
my %constructors_converse_deps;
my %registrations_converse_deps;
my %requirements_converse_deps;
my %definitions_converse_deps;
my %theorems_converse_deps;
my %schemes_converse_deps;

sub initialize_all_article_dependencies {
  foreach my $article (@mml_lar) {
    my @article_deps = article_dependencies ($article);
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

sub article_dependencies {
  my $article = shift ();
  my $article_temp_dir = $tempdir . "/" . $article;
  # Call envget and use the evl2txt XSLT sheet to get the dependenceis
  # for each article.  Die immediately if anything goes wrong.
  my ($envget_exit_status, $xsltproc_exit_status);
  my ($article_evl, $article_err, $article_dep);
  system ("cd", $article_temp_dir);
  system ("$envget $article.miz");
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
  $article_evl = $article . ".evl";
  $article_dep = $article . ".dep";
  system ("xsltproc", "--output", $article_dep, $evl2txt, $article_evl);
  $xsltproc_exit_status = ($? >> 8);
  unless ($xsltproc_exit_status == 0) {
    # Ditto.
    croak ("xsltproc did not exit cleanly when given $article_evl");
  }
  chdir ($currdir);

  # Parse the output from generated by applying the evl2txt sheet.
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
  foreach my $article (@mml_lar) {
    my $artcle_temp_dir = $tempdir . "/" . $article;
    $article_dep = $article . ".dep";
    system ("cd", $article_temp_dir);
    my $article_dep_fh;
    open ($article_dep_fh, q{<}, $article_dep)
      or croak ("Unable to open article dependency file $article_dep under $article_temp_dir!");
    $dep_line = <$article_dep_fh>;
    unless (defined ($dep_line)) {
      croak ("The first line of $article_temp_dir/$article_dep evidently doesn't exist");
    }
    close ($article_dep_fh);
    @dep_line_fields = split (/\(/x,$dep_line);
    foreach my $semi_dep_line_field (@dep_line_fields) {
      # should look like: "vocabularies ... )".  First, delete the trailing " )"
      $dep_line_field = substr ($semi_dep_line_field, -2);
      my @dep_line_entries = split (/\ /x,$dep_line_field);
      my $first_element = pop (@dep_line_entries);

      if ($first_element eq "vocabularies") {
	@article_vocabularies = \@dep_line_entries;
      }
      
      if ($first_element eq "notations") {
	@article_notations = \@dep_line_entries;
      }
      
      if ($first_element eq "constructors") {
	@article_constructors = \@dep_line_entries;
      }
      
      if ($first_element eq "registrations") {
	@article_registrations = \@dep_line_entries;
      }
      
      if ($first_element eq "requirements") {
	@article_requirements = \@dep_line_entries;
      }
      
      if ($first_element eq "definitions") {
	@article_definitions = \@dep_line_entries;
      }
      
      if ($first_element eq "theorems") {
	@article_theorems = \@dep_line_entries;
      }
      
      if ($first_element eq "schemes") {
	@article_schemes = \@dep_line_entries;
      }
    }
    system ("cd", $currdir);
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
  my %relation = %{shift ()};
  my %converse = ();
  my $elt;
  my $range_elt;
  my @range;
  my @domain;
  foreach my $elt (keys (%relation)) {
    @range = @{$relation{$elt}};
    foreach my $range_elt (@range) {
      @domain = @{$converse{$range_elt}};
      push (@domain, $elt);
      $converse{$range_elt} = \@domain;
    }
  }
  return (%converse);
}

read_mml_lar ();
copy_mml_lar ();
initialize_all_article_dependencies ();

sub compute_converses {
  my %vocaularies_converse_deps = converse (%vocabularies_deps);
  my %notations_converse_deps = converse (%notations_deps);
  my %constructors_converse_deps = converse (%constructors_deps);
  my %registrations_converse_deps = converse (%registrations_deps);
  my %requirements_converse_deps = converse (%requirements_deps);
  my %definitions_converse_deps = converse (%definitions_deps);
  my %theorems_converse_deps = converse (%theorems_deps);
  my %schemes_converse_deps = converse (%schemes_deps);
}


