#!/usr/bin/perl -w

=head1 NAME

MizItemize.pl file ( create items from .miz and .xml files)

=head1 SYNOPSIS

MizItemize.pl ~/a

=cut

use strict;
use Getopt::Long;

my ($goutdir, $gindir);

Getopt::Long::Configure ("bundling");

GetOptions('outdir|o=s'    => \$goutdir,
	   'indir|i=s'    => \$gindir
);

pod2usage(2) if ($#ARGV != 0);


my $filestem   = shift(@ARGV);

$goutdir = "." unless(defined($goutdir));
$gindir = "." unless(defined($gindir));

my $miz = $filestem . ".miz";
my $xml = $filestem . ".xmlvrf";

my @lines=();

open(MIZ,"$gindir/$miz") or die "No $miz!";
while($_=<MIZ>) { push(@lines, $_); };
close(MIZ);

# Get theorem Propositions' positions
open(XML, "$gindir/$xml") or die "Mo $xml!";
local $/;$_=<XML>;

# Search XML for theorem positions,
# and print theorems with proofs to files
while(m/((<JustifiedTheorem)(.|[\n])*?<\/JustifiedTheorem>)/g)
{
#DEBUG    print $2, "\n";
## This is fragile, could be done by xslt processing (slightly slower)
if($1=~m/<JustifiedTheorem.*[\n]<Proposition.*line=\"([0-9]+)\".*col=\"([0-9]+)\"(.|[\n])*?<EndPosition.*line=\"([0-9]+)\".*col=\"([0-9]+)\"\/> *[\n]*<\/Proof> *[\n]*<\/JustifiedTheorem>/)
{
    my ($l1,$c1,$l2,$c2) = ($1,$2,$4,$5);
#DEBUG    print join(",",($l1,$c1,$l2,$c2)), "\n";
    my $thname = $filestem . "__" . $l1 . "_" . $c1;
    my $l0 = $l1;
    my $th = $lines[$l0];
    while(!($th =~ m/\btheorem\b/)) {$th = $lines[$l0--];}
    open(F,">$goutdir/$thname") or die "Not writable: $goutdir/$thname" ;
    while(++$l0<=$l2) { print F $lines[$l0]; }
    close(F);
}}
close(XML);



