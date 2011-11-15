#!/usr/bin/perl

%h=();
$_=<>;
chop;
m/(.*):(.*)/;
($k,$l)=($1,$2);
@aa=split(/\ +/,$l);
@h{@aa} = ();
my @bb= ();
foreach my $v (keys %h) { push(@bb, "mml/$v"); }
print "$k: ";
print join(" ", keys %h);
print "\n";
# print "\t\@touch $k\n";
