#!/usr/bin/perl -w

use strict;
use warnings;

%h=(); 
$_=<>;
chop; 
m/(.*):(.*)/;
($k,$l)=($1,$2); 
@aa=split(/\ +/,$l);
@h{@aa} = ();
print "$k: "; 
print join(" ", keys %h);
