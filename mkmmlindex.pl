#!/usr/bin/perl -w

## Create a HTML file describing the headers of Mizar articles.

## SYNOPSIS:
## mkmmlindex.pl *.hdr > abcmiz_mmlindex.html

use strict;
use File::Basename;
use Getopt::Long;
use Pod::Usage;

## TODO: this two should be options
my $lgitwebcgi    = "http://mws.cs.ru.nl:1234/";
my $lmwikicgi     = "http://mws.cs.ru.nl/cgi-bin/mwiki.cgi";
my $git_project = "mw1.git";
my $htmlroot = "";
my $dependencies = 0; ## if 1, omit the header and footer

my ($help, $man);

Getopt::Long::Configure ("bundling");

GetOptions('gitwebcgi|g=s'    => \$lgitwebcgi,
	   'mwikicgi|m=s'    => \$lmwikicgi,
	   'project|p=s'    => \$git_project,
	   'dependencies|d=i'    => \$dependencies,
	   'htmlroot|H=s'    => \$htmlroot,
	   'help|h'          => \$help,
	   'man'             => \$man)
    or pod2usage(2);

pod2usage(1) if($help);
pod2usage(-exitstatus => 0, -verbose => 2) if($man);

pod2usage(2) if ($#ARGV < 0);

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
    print "<dt><a href=\"$htmlroot$name.html\">$name_uc</a>,</dt><dd>$all{$name}->[1]. <i>$all{$name}->[0]</i></dd>\n"
}

my $header=<<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 3.2//EN">
<head>
<title>Mizar Mathematical Library (current wiki state), Index of Identifiers</title>
<style type="text/css">
	body {font-family: monospace; margin: 0px;}
	.wikiactions ul { background-color: DarkSeaGreen ; color:blue; margin: 0; padding: 6px; list-style-type: none; border-bottom: 1px solid #000; }
	.wikiactions li { display: inline; padding: .2em .4em; }
        div.index {padding-left: 3mm;}
</style>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
</head>
<body>
 <div  class="wikiactions">
    <ul>
         <li> <a href="$lmwikicgi?p=$git_project;a=gitweb">Gitweb</a> </li>
         <li> <a href="$lmwikicgi?p=$git_project;a=register">Register</a> </li>
    </ul>
</div>
<div class=index>
<div class=indexheading>
<form method="post" action="$lmwikicgi" enctype="multipart/form-data">
<table align=right>
<tr>
<td align=top>
                <input type="text" name="f" value="mml/foo.miz" SIZE="20">
</td>
          <input type="hidden" name="p" value="$git_project">
          <input type="hidden" name="a" value="edit">

        <td align=right>
          <input type="submit" value="Create/Edit">
         </td>
</tr>
</table>
</form>
<h1>
Mizar Mathematical Library (current wiki state)
</h1>
</div>
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
END

my $footer=<<END;
</dd>
</dl>
</div>
<hr/>
</body>
</html>
END


print $header if($dependencies==0);
print '<dl>';
my @names = sort keys %all;
if($#names >= 0)
{
    my $prevletter = uc(substr($names[0], 0, 1));
    print ('<dt><A NAME="', $prevletter, '"><b>', $prevletter, '</B></A><dd><dl>', "\n");

    foreach my $name (@names)
    {
	unless ($prevletter eq uc(substr($name, 0, 1)))
	{
	    $prevletter = uc(substr($name, 0, 1));
	    print ('</dl>', "\n", '<dt><A NAME="', $prevletter, '"><b>', $prevletter, '</B></A><dd><dl>', "\n");
	}
	print_one_html($name);
    }
}
print '</dl>';
print $footer if($dependencies==0);
