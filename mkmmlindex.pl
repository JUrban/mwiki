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
    my ($name, $directories, $suffix) = fileparse($file, qr/\.[^.]*/);
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
    print "<dt><a href=\"$name.html\">$name_uc</a>,</dt><dd>$all{$name}->[1]. <i>$all{$name}->[0]</i></dd>\n"
}

my $header=<<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>Mizar Mathematical Library (current wiki state), Index of Identifiers</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
</head>
<body>
<h1>
<a href="index.html"> Mizar Mathematical Library (current wiki state)</a>,
Index of MML Identifiers
</h1>
<hr/>
<p>
[<a href="#A">A</a>,
<a href="#B">B</a>,
<a href="#C">C</a>,
<a href="#D">D</a>,
<a href="#E">E</a>,
<a href="#F">F</a>,
<a href="#G">G</a>,
<a href="#H">H</a>,
<a href="#I">I</a>,
<a href="#J">J</a>,
<a href="#K">K</a>,
<a href="#L">L</a>,
<a href="#M">M</a>,
<a href="#N">N</a>,
<a href="#O">O</a>,
<a href="#P">P</a>,
<a href="#Q">Q</a>,
<a href="#R">R</a>,
<a href="#S">S</a>,
<a href="#T">T</a>,
<a href="#U">U</a>,
<a href="#V">V</a>,
<a href="#W">W</a>,
<a href="#X">X</a>,
<a href="#Y">Y</a>,
<a href="#Z">Z</a>]</p>
<hr/>
<dl>
END

my $footer=<<END;
</dl>
</dd>
</dl>
<hr/>
</body>
</html>
END


print $header;
my $prevletter;
foreach my $name (sort keys %all)
  {
    my $firstletter = uc (substr ($name, 0, 1));
    unless (defined $prevletter) {
      $prevletter = $firstletter;
      print "<dt>$firstletter</dt>";
      print '<dd>';
      print '<dl>';
    }

    unless ($prevletter eq $firstletter)
      {
	print ('</dl></dd>', "\n", '<dt><a name="', $prevletter, '"><b>', $prevletter, '</b></a></dt><dd><dl>', "\n");
      }

    print_one_html($name);
  }
print $footer;
