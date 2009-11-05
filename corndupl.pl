#!/usr/bin/perl -w

=head1 NAME

corndupl.pl ( get list of items from a .dpd files created by DPD graph, print and htmlize duplications)

=head1 SYNOPSIS

# print all dependencies of CRTrans recursively using dpdgraph (Coqthmdep) to CRTrans.dpd:
i=CRTrans; echo "Require $i. Set DependGraph File \"$i.dpd\". Print FileDependGraph."| /home/urban/corn_stable/CoRN/bin/CoRNthmdep

# htmlize the duplications
./corndupl.pl CRTrans.dpd > CornDupl.html

=cut

my $coqroot = "http://coq.inria.fr/library/";
my $cornroot = "http://c-corn.cs.ru.nl/documentation/";


while(<>)
{
    if(m/^N:[^"]*"([^"]*)" *.*path="((Coq|CoRN).[^"]*)".*/)
    {
	$h{$1} = [] unless exists $h{$1};
	push( @{$h{$1}}, $2);
    }
}

print "<html><body>";

foreach my $name (sort keys %h)
{
    if (scalar( @{$h{$name}} ) > 1)
    {
	foreach $path ( @{$h{$name}} )
	{
	    my $root;
	    if ($path =~ m/^CoRN.*/) { $root = $cornroot } else { $root = $coqroot }
	    print "<a href=\"$root$path.html\#$name\">$name in $path</a><p/>\n";
	}
    }
}

print "</body></html>";

