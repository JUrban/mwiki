#!/usr/bin/perl -w

=head1 NAME

setup_mizar_wiki.pl [options] (setup the mizar wiki)

=head1 SYNOPSIS

setup_mizar_wiki -d my_wiki -M git@mws.cs.ru.nl:/home/git/mwiki

 Options:
   --directory=<arg>,       -d<arg>
   --remotemaster=<arg>,    -M<arg>
   --help,                  -h
   --man

=head1 OPTIONS

=over 8

=item B<<< --directory=<arg>, -d<arg> >>>

The directory name/prefix.

=item B<<< --remotemaster=<arg>, -B<M><arg> >>>

The default remote master used for pushing.

=item B<<< --help, -h >>>

Print a brief help message and exit.

=item B<<< --man >>>

Print the manual page and exit.

=back

=head1 DESCRIPTION

This program install the mizar wiki locally.

=head1 CONTACT

Josef Urban firstname.lastname(at)gmail.com
Jesse Alama firstnamelastname(at)gmail.com

=head1 LICENCE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut

use strict;
use warnings;
use File::Temp qw/ tempfile tempdir /;
use Cwd;
use Carp;

use Mizar;


use Pod::Usage;
use Getopt::Long;
use XML::LibXML;
use File::Spec;


my ($gdirectory, $gremotemaster);

my ($gquiet, $help, $man);


Getopt::Long::Configure ("bundling");

GetOptions('directory|d=s'    => \$gdirectory,
	   'remotemaster|P=i'    => \$gremotemaster,
	   'help|h'          => \$help,
	   'man'             => \$man)
    or pod2usage(2);

pod2usage(1) if($help);
pod2usage(-exitstatus => 0, -verbose => 2) if($man);

pod2usage(2) if ($#ARGV != 0);



## TODO: take the ikiwiki setup bits - generate the secure wrappers,
## etc.  We will mimic the ikiwiki setup with the working repo used for
## web edits, and the bare repo used for post-commit hook updating the
## working repo, and ikiwiki updating the html from the working repo. The
## bare repo will have a pre-receive and pre-commit hooks, for security
## and depndency checking and verification, and post-commit for updating
## the working repo and htmlization.


## we should setup things for anonymous push, following the instructions
## at http://ikiwiki.info/tips/untrusted_git_push/

## pseudo code follows:

# add anonymous user
sub AddAnonUser { system("adduser --shell=/usr/bin/git-shell --disabled-password anon"); }

# unix users whose commits should be checked by the pre-receive hook
# untrusted_committers => ['anon'],
sub SetupUntrustedCommitters {};


# The untrusted_committers list is the list of unix users who will be pushing in untrusted changes.
# It should not include the user that ikiwiki normally runs as.
sub SetupGitPreReceiveHook  {};


# One way to do it is to create a group, and put both anon and your
# regular user in that group. Then make the bare git repository owned
# and writable by the group. See git for some more tips on setting up a
# git repository with multiple committers.  Note that anon should not be
# able to write to the srcdir, only to the bare git repository for your
# wiki.

sub SetupGitRepoPermissions {};

# Now set up git-daemon. It will need to run as user anon, and be
# configured to export your wiki's bare git repository. I set it up as
# follows in /etc/inetd.conf, and ran /etc/init.d/openbsd-inetd restart.
# git     stream  tcp     nowait  anon          /usr/bin/git-daemon git-daemon --inetd --export-all --interpolated-path=/srv/git/%H%D /srv/git
#
# At this point you should be able to git clone git://your.wiki/path
# from anywhere, and check out the source to your wiki. But you won't be
# able to push to it yet, one more change is needed to turn that
# on. Edit the config file of your bare git repository, and allow
# git-daemon to receive pushes:

# [daemon]
#     receivepack = true

# Now pushes should be accepted, and your wiki immediatly be updated. If
# it doesn't, check your git repo's permissions, and make sure that the
# post-update and pre-receive hooks are suid so they run as the user who
# owns the srcdir.


sub SetupGitDaemon {}

AddAnonUser();
SetupUntrustedCommitters();
SetupGitPreReceiveHook();
SetupGitRepoPermissions()
SetupGitDaemon();


