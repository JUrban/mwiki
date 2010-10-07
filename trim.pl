#!/usr/bin/perl -w

my $article = $ARGV[0];
my $article_prel_dir = "/tmp/mml/subset_1/prel";

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

sub trim_notations_directive {
  my $notations_ref = shift;
  my @notations = @{$notations_ref};
  my @trimmed = ();
  foreach my $notation (@notations) {
    if (grep (/^$notation$/i, @mml_lar)) {
      push (@trimmed, $notation);
    } elsif ($notation eq 'TARSKI') {
      push (@trimmed, $notation);
    } elsif (-e "$article_prel_dir/$notation.dno") {
      push (@trimmed, $notation);
    }
  }
  return \@trimmed;
}

sub trim_constructors_directive {
  my $constructors_ref = shift;
  my @constructors = @{$constructors_ref};
  my @trimmed = ();
  foreach my $constructor (@constructors) {
    if (grep (/^$constructor$/i, @mml_lar)) {
      push (@trimmed, $constructor);
    } elsif ($constructor eq 'TARSKI') {
      push (@trimmed, $constructor);
    } elsif (-e "$article_prel_dir/$constructor.dco") {
      push (@trimmed, $constructor);
    }
  }
  return \@trimmed;
}

sub trim_registrations_directive {
  my $registrations_ref = shift;
  my @registrations = @{$registrations_ref};
  my @trimmed = ();
  foreach my $registration (@registrations) {
    if (grep (/^$registration$/i, @mml_lar)) {
      push (@trimmed, $registration);
    } elsif ($registration eq 'TARSKI') {
      push (@trimmed, $registration);
    } elsif (-e "$article_prel_dir/$registration.dcl") {
      push (@trimmed, $registration);
    }
  }
  return \@trimmed;
}

sub trim_definitions_directive {
  my $definitions_ref = shift;
  my @definitions = @{$definitions_ref};
  my @trimmed = ();
  foreach my $definition (@definitions) {
    if (grep (/^$definition$/i, @mml_lar)) {
      push (@trimmed, $definition);
    } elsif ($definition eq 'TARSKI') {
      push (@trimmed, $definition);
    } elsif (-e "$article_prel_dir/$definition.def") {
      push (@trimmed, $definition);
    }
  }
  return \@trimmed;
}

sub trim_theorems_directive {
  my $theorems_ref = shift;
  my @theorems = @{$theorems_ref};
  my @trimmed = ();
  foreach my $theorem (@theorems) {
    # DEBUG
    warn ("Looking for $theorem in $article_prel_dir/$theorem.the...");
    if (grep (/^$theorem$/i, @mml_lar)) {
      push (@trimmed, $theorem);
    } elsif ($theorem eq 'TARSKI') {
      push (@trimmed, $theorem);
    } elsif (-e "$article_prel_dir/$theorem.the") {
      push (@trimmed, $theorem);
    }
  }
  return \@trimmed;
}

sub trim_schemes_directive {
  my $schemes_ref = shift;
  my @schemes = @{$schemes_ref};
  my @trimmed = ();
  foreach my $scheme (@schemes) {
    if (grep (/^$scheme$/i, @mml_lar)) {
      push (@trimmed, $scheme);
    } elsif ($scheme eq 'TARSKI') {
      push (@trimmed, $scheme);
    } elsif (-e "$article_prel_dir/$scheme.sch") {
      push (@trimmed, $scheme);
    }
  }
  return \@trimmed;
}

# article environment
my @vocabularies = `/Users/alama/sources/mizar/mwiki/env.pl Vocabularies $article`;
my @notations = `/Users/alama/sources/mizar/mwiki/env.pl Notations $article`;
my @constructors = `/Users/alama/sources/mizar/mwiki/env.pl Constructors $article`;
my @registrations = `/Users/alama/sources/mizar/mwiki/env.pl Registrations $article`;
my @requirements = `/Users/alama/sources/mizar/mwiki/env.pl Requirements $article`;
my @definitions = `/Users/alama/sources/mizar/mwiki/env.pl Definitions $article`;
my @theorems = `/Users/alama/sources/mizar/mwiki/env.pl Theorems $article`;
my @schemes = `/Users/alama/sources/mizar/mwiki/env.pl Schemes $article`;

chomp (@vocabularies);
@vocabularies = grep (!/^HIDDEN$/, @vocabularies);
chomp (@notations);
@notations = grep (!/^HIDDEN$/, @notations);
chomp (@constructors);
@constructors = grep (!/^HIDDEN$/, @constructors);
chomp (@registrations);
@registrations = grep (!/^HIDDEN$/, @registrations);
chomp (@requirements);
@requirements = grep (!/^HIDDEN$/, @requirements);
chomp (@definitions);
@definitions = grep (!/^HIDDEN$/, @definitions);
chomp (@theorems);
@theorems = grep (!/^HIDDEN$/, @theorems);
chomp (@schemes);
@schemes = grep (!/^HIDDEN$/, @schemes);

# DEBUG
warn ("Theorems:\n");
foreach my $theorem (@theorems) {
  print ("$theorem\n");
}

my $trimmed_notations_ref = trim_notations_directive (\@notations);
my $trimmed_constructors_ref = trim_constructors_directive (\@constructors);
my $trimmed_registrations_ref = trim_registrations_directive (\@registrations);
my $trimmed_definitions_ref = trim_definitions_directive (\@definitions);
my $trimmed_theorems_ref = trim_theorems_directive (\@theorems);
my $trimmed_schemes_ref = trim_schemes_directive (\@schemes);

my @trimmed_notations = @{$trimmed_notations_ref};
my @trimmed_constructors = @{$trimmed_constructors_ref};
my @trimmed_registrations = @{$trimmed_registrations_ref};
my @trimmed_definitions = @{$trimmed_definitions_ref};
my @trimmed_theorems = @{$trimmed_theorems_ref};
my @trimmed_schemes = @{$trimmed_schemes_ref};

open (MIZ, q{<}, "$article.miz")
  or die ("Coudn't open read-only filehandle for $article.miz: $!");
my $line;
while (defined ($line = <MIZ>)) {
  chomp $line;
  if ($line =~ /^notations /) {
    print ('notations ' . join (', ', @trimmed_notations) . ";\n");
  } elsif ($line =~ /^constructors /) {
    print ('constructors ' . join (', ', @trimmed_constructors) . ";\n");
  } elsif ($line =~ /^registrations /) {
    print ('registrations ' . join (', ', @trimmed_registrations) . ";\n");
  } elsif ($line =~ /^definitions /) {
    print ('definitions ' . join (', ', @trimmed_definitions) . ";\n");
  } elsif ($line =~ /^theorems /) {
    print ('theorems ' . join (', ', @trimmed_theorems) . ";\n");
  } elsif ($line =~ /^schemes /) {
    print ('schemes ' . join (', ', @trimmed_schemes) . ";\n");
  } else {
    print ("$line\n");
  }
}

close (MIZ)
  or die ("Couldn't close read-only filehandle for miz!")
