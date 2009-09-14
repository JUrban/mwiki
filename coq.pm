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


	return coqdoc($pname, $content);
}


# Run coqdoc on $content, giving the file name $pname.v, return the html
# Creates temp dir in /tmp, which should be removed at some point (after debuging).
sub coqdoc {
    my ($pname, $content) = @_;
    my $ProblemFile = $pname . '.v';
#    my $TemporaryDirectory = "/tmp/";
#    my $TemporaryProblemDirectory = "$TemporaryDirectory/coq_$$";
    my $TemporaryProblemDirectory = mkdtemp("/tmp/coq_XXXX");
    my $PidNr = $$;

#    if (!mkdir($TemporaryProblemDirectory,0777)) {
#        print("ERROR: Cannot make temp dir $TemporaryProblemDirectory\n");
#        die("ERROR: Cannot make temp dir $TemporaryProblemDirectory\n");
#    }

    system("chmod 0777 $TemporaryProblemDirectory");


    open(PFH, ">$TemporaryProblemDirectory/$ProblemFile") or die "$ProblemFile not writable";
    printf(PFH "%s",$content);
    close(PFH);

    my $result = `cd $TemporaryProblemDirectory; /home/urban/corn_stable/CoRN/bin/CoRNc $ProblemFile; coqdoc --no-index --body-only --stdout $ProblemFile |tee $ProblemFile.html`;
    $result =~ s/\"[a-zA-Z0-9_-]+\.html\#/\"\#/g;

#    system("rm -rf $TemporaryProblemDirectory");

    return $result;
}


1
