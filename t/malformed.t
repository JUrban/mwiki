#!/usr/bin/perl

# A collection of perl tests for testing out scripts.
#
# Currently, this script just initializes a new (non-bare) git repo,
# copies the MML to it, commits the whole thing, then tries
# progressively to add some content.  The idea is to test our hooks
# and other tools for ensuring coherence of the MML.  That's not
# happening at the moment.  We should call git-init with some
# pre-populated content (`git init --template=...').

use Test::More tests => 6;

######################################################################
### Load the git module
######################################################################

BEGIN { use_ok ('File::Temp', 'tempdir'); }
BEGIN { use_ok ('File::Copy'); }
BEGIN { use_ok ('Git'); }
BEGIN { use_ok ('mizar'); }

#######################################################################
### Create a repo in a temporary directory and copy the MML into it
######################################################################

my $temp_mml = tempdir (CLEANUP => 0);
chdir ($temp_mml);
Git::command_noisy ('init');
my $repo = Git->repository ($temp_mml);

# Copy the MML to the new working directory
ok (mizar::copy_mml_to_dir ($temp_mml), "copy MML to temporary directory");

# Add everything to the repo...
foreach my $mml_id (mizar::get_MML_LAR ()) {
  unless ($mml_id eq "tarski") {
    $repo->command_noisy ('add', "mml/$mml_id.miz");
  }
}
# ...and commit.
$repo->command_noisy ('commit', '-m initial');

######################################################################
### A contribution!
######################################################################

my $trivial_article = <<END;
environ

 vocabularies TARSKI, XBOOLE_0;
 notations TARSKI;
 constructors TARSKI;
 theorems TARSKI;
 schemes TARSKI;

begin

reserve x for set;

theorem
for x holds x = x;
END

# Put it into the repo
my $trivial_article_ident = "awesome";
my $trivial_article_fh;
my $trivial_article_filename = "$temp_mml/mml/$trivial_article_ident.miz";

ok ( !(-e $trivial_article_filename), 
	 "make sure to not overwrite something in the MML: $trivial_article_ident already exists");

open ($trivial_article_fh, q{>}, $trivial_article_filename)
  or die ("Ouch: we couldn't open $trivial_article_filename for writing");
print $trivial_article_fh ($trivial_article);
close ($trivial_article_fh)
  or die ("Ouch: there was an error closing the filehandle for $trivial_article_filename");

# Add it to the repo
$repo->command_noisy ('add', "mml/$trivial_article_ident.miz");
$repo->command_noisy ('commit', '-m "Signed-off-by: Adam Naumowicz"');

######################################################################
### Editing non-exportable items
######################################################################

# Add a header
my $trivial_article_with_header
  = ":: My awesome article\n\n:: by Jesse Alama\n\n" . $trivial_article;

# Do the same as above: save this new article and try to commit it.
open ($trivial_article_fh, q{>}, $trivial_article_filename)
  or die ("Ouch: we couldn't open $trivial_article_filename for writing");
print $trivial_article_fh ($trivial_article_with_header);
close ($trivial_article_fh)
  or die ("Ouch: there was an error closing the filehandle for $trivial_article_filename");

# Add it to the repo
$repo->command_noisy ('add', "mml/$trivial_article_ident.miz");
$repo->command_noisy ('commit', '-m "Add a header\n\nSigned-off-by: Adam Naumowicz"');


######################################################################
### Destructively overwrite something in the MML
######################################################################

######################################################################
### Delete something from the MML
######################################################################
