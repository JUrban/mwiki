#!/usr/bin/perl
# CoqDoc and Coq plugin
# based on the WikiText plugin.
package IkiWiki::Plugin::coq;

use warnings;
use strict;
use IkiWiki 3.00;
use File::Temp qw/ :mktemp  /;
use File::Basename;


sub import {
	hook(type => "getsetup", id => "v", call => \&getsetup);
	hook(type => "htmlize", id => "v", call => \&htmlize);
}

sub getsetup {
	return
		plugin => {
			safe => 1,
			rebuild => 1, # format plugin
		},
}

sub htmlize (@) {
	my %params=@_;
	my($pname, $directories, $suffix) = fileparse($params{page});
#	my $pname = $params{page};
	my $content = $params{content};


	return coqdoc($pname, $directories, $content);
}


# Run coqdoc on $content, giving the file name $pname.v, return the html
# Can create temp dir in /tmp, which should be removed at some point (after debuging).
sub coqdoc {
    my ($pname, $directories, $content) = @_;
    my $ProblemFile = $pname . '.v';
    my $GlobFile = $pname . '.glob';
    my $result = "";

    # set to 0 for doing things in $config{srcdir} (preferred),
    # set to 1 for doing things in /tmp
    my $DoTmp = 0;

    # set to 0 if no coqc (eg only coqdoc);
    # useful for initial populating of the wiki (provided the .vo files exist)
    my $DoVerif = 1;

    # the verifier;
    # ##TODO: should be instantiated to the current repo, 
    #         different coq versions, ssreflect, cornc, etc
    my $coqc =  ($DoVerif == 0)? "true": "/home/urban/corn_stable/CoRN/bin/CoRNc";

    # coqdoc binary
    my $coqdoc = "/home/urban/bin/coqdoc";



    if($DoTmp == 1)
    {
	my $TemporaryProblemDirectory = mkdtemp("/tmp/coq_XXXX");

	system("chmod 0777 $TemporaryProblemDirectory");


	open(PFH, ">$TemporaryProblemDirectory/$ProblemFile") or die "$ProblemFile not writable";
	printf(PFH "%s",$content);
	close(PFH);

	$result = `cd $TemporaryProblemDirectory; $coqc $ProblemFile; $coqdoc --no-index --body-only --stdout $ProblemFile |tee $ProblemFile.html; cp $GlobFile $config{srcdir}/$directories$GlobFile`;
    }
    else
    {
	open(PFH, ">$config{srcdir}/$directories$ProblemFile") or die "$ProblemFile not writable";
	printf(PFH "%s",$content);
	close(PFH);

	$result = `cd $config{srcdir}/$directories; /home/urban/corn_stable/CoRN/bin/CoRNc $ProblemFile; $coqdoc --external bla CoRN --no-index --body-only --stdout $ProblemFile |tee $ProblemFile.html`;
    }

    $result =~ s/\"[a-zA-Z0-9_-]+\.html\#/\"\#/g;

#    system("rm -rf $TemporaryProblemDirectory");

    return '<link href="'. $config{url} . '/coqdoc.css" rel="stylesheet" type="text/css"/>' . "\n". $result;
}


1
