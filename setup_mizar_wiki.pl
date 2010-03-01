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



