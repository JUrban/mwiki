package mw_common;

 ## The common math wiki finctions should be moved here

use strict;
use warnings;
use File::Basename;
use Cwd;
use Exporter qw(import);
our @EXPORT_OK = qw(MWUSER REPO_NAME MW_BTRFS GITWEB_ROOT);


# the MWUSER - everything is now in his gitolite, this should be in sync with Makefile.smallinstall
use constant MWUSER => "@@MWUSER@@";

# the REPO_NAME - sync with Makefile.smallinstall, all gitweb repos dwell bellow this dir
use constant REPO_NAME	  => "@@REPO_NAME@@";

# do we use the btrfs cloning?- sync with smallinstall
use constant MW_BTRFS	  => "@@MW_BTRFS@@";

# gitweb

use constant GITWEB_ROOT   => "@@GITWEB_ROOT@@";

# assumes the right directory
sub set_git_var
{
    my ($key, $value) = @_;
    system("git config  $key $value");
}

# assumes the right directory
sub set_git_vars
{
    my $vars = shift;
    foreach my $key (keys %$vars)
    {
	set_git_var($key, $vars->{$key});
    }
}

sub clone_full_dirs
{
    my ($MW_BTRFS,$origin,$clone) = @_;
    my ($clone_output, $clone_exit_code);

    if ($MW_BTRFS == 1)
    {
	$clone_output = `btrfs subvolume snapshot  $origin $clone 2>&1`;
    }
    else
    {
	$clone_output = `rsync -a --del $origin/ $clone 2>&1`;
    }

    return ($?, $clone_output);
}


1;
