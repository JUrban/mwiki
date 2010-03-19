#!/usr/bin/perl

%h=();
$_=<>;
chop;
m/(.*):(.*)/;
($k,$l)=($1,$2);
@aa=split(/\ +/,$l);
@h{@aa} = ();
print "$k: ";
print join(" ", keys %h);
print "\n";
print "\t\@touch $k\n";
