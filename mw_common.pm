 package mw_common;

 ## The common math wiki finctions should be moved here

 use strict;
 use warnings;
 use File::Basename;
 use Cwd;



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
