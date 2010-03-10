#!/usr/bin/perl -w

## Create a HTML file describing the headers of Mizar articles.

## SYNOPSIS:
## mkmmlindex.pl *.hdr > abcmiz_mmlindex.html

use strict;
use File::Basename;

my ($title, $authors, $date, $copyright);
$title = "";

my %all = ();

while (my $file = shift)
{
    open(F,$file);
    my ($name, $directories, $suffix) = fileparse($file);
    $all{$name} = [];
    while($_=<F>)
    {
	if(m/<dc:title>(.*)<\/dc:title>/) { $all{$name}->[0]= $1; }
	if(m/<dc:creator>(.*)<\/dc:creator>/) { $all{$name}->[1]= $1; }
	if(m/<dc:date>(.*)<\/dc:date>/) { $all{$name}->[2]= $1; }
	if(m/<dc:rights>(.*)<\/dc:rights>/) { $all{$name}->[3]= $1; }
    }
    close(F);
}

sub print_one_html
{
    my ($name) = @_;
    my $name_uc = uc($name);
    print "<dt><A HREF=\"$name.html\">$name_uc</A>,<dd>
$all{$name}->[1].<dd>
<I>$all{$name}->[0]</I>
"
}

my $header=<<END;
<!DOCTYPE HTML PUBLIC  "-//IETF//DTD HTML 2.0//EN">
<html>
<head>
<title>
Mizar Mathematical Library (current wiki state), Index of Identifiers
</title>
</head>
<body>
<h1>
<a href="index.html"> Mizar Mathematical Library (current wiki state)</a>,
Index of MML Identifiers
</h1>
<hr>
<p>
<hr>
<dl>
END

my $footer=<<END;
</dl>
</dl>
<p>
<hr>
<hr>
</body>
</html>
END


print $header;
foreach my $name (sort keys %all)
{
    print_one_html($name);
}
print $footer;
