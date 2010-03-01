#!/usr/bin/perl -w

use Test::More tests => 3;

######################################################################
### Load the git module
######################################################################

BEGIN { use_ok ('File::Temp', 'tempdir'); }
BEGIN { use_ok ('Git'); }

######################################################################
### Try to make a repo in a temporary directory
######################################################################

my $tempdir = tempdir (CLEANUP => 1);
chdir ($tempdir);
Git::command_noisy ('init');
my $repo = Git->repository (Directory => $tempdir);

ok (defined ($repo), "make a new git repo");
