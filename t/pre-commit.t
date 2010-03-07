use Test::More tests => 5;

use File::Temp qw/ tempdir /;

# Testing out git hooks.  Simulate a variety of edits that could be
# done to an MML that is known to be correct.

my $main_repo = "/Users/alama/sources/mizar/mwiki/t/hooks/main-repo";
my $temp_mml = tempdir ();

git clone $main_repo "$temp_mml/devel-repo";
