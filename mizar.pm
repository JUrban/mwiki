#!/usr/bin/perl
# Mizar plugin
# based on the WikiText plugin.
package IkiWiki::Plugin::mizar;

use warnings;
use strict;
use IkiWiki 3.00;
use File::Temp qw/ :mktemp  /;
use File::Basename;


sub import {
        add_underlay("javascript");
	hook(type => "getsetup", id => "miz", call => \&getsetup);
	hook(type => "htmlize", id => "miz", call => \&htmlize);
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


	return verify($pname, $content);
}

# extensions of the environmental files
my @gaccexts = (".aco", ".atr", ".dct", ".dfs", ".eid", ".ere", ".esh", ".evl", ".frm", ".prf", ".vcl",
	       ".ano", ".cho", ".dcx", ".ecl", ".eno", ".eth", ".fil", ".nol", ".sgl");

# extensions of files created/used by verifier, with exception of the .xml file 
my @gvrfexts = ('.frx', '.idx', '.miz', '.par', '.ref');


# Run mizar on $content, giving the file name $pname.miz, return the html
# Creates temp dir in /tmp, which should be removed at some point (after debuging).
sub verify {
    my ($pname, $content) = @_;
    my $ProblemFile = $pname . '.miz';
    my $ProblemFileXml = $pname . '.xml';
#    my $TemporaryDirectory = "/tmp/";
#    my $TemporaryProblemDirectory = "$TemporaryDirectory/coq_$$";
    my $TemporaryProblemDirectory = mkdtemp("/tmp/mml_XXXX");
    my $PidNr = $$;
    my $mizfiles = '/home/mizarw/mwiki';
    my $Xsl4MizarDir = $mizfiles;  # "/home/urban/gitrepo/xsl4mizar";
    my $addabsrefs = "$Xsl4MizarDir/addabsrefs.xsl";
    my $miz2html = "$Xsl4MizarDir/miz.xsl";

#    if (!mkdir($TemporaryProblemDirectory,0777)) {
#        print("ERROR: Cannot make temp dir $TemporaryProblemDirectory\n");
#        die("ERROR: Cannot make temp dir $TemporaryProblemDirectory\n");
#    }

    system("chmod 0777 $TemporaryProblemDirectory");

    open(PFH, ">$TemporaryProblemDirectory/$ProblemFile") or die "$ProblemFile not writable";
    printf(PFH "%s",$content);
    close(PFH);

    my $result = `export MIZFILES=$mizfiles; cd $TemporaryProblemDirectory; $mizfiles/bin/accom $ProblemFile 2>&1 > $ProblemFile.erracc; $mizfiles/bin/verifier -q $ProblemFile 2>&1 > $ProblemFile.errvrf; xsltproc $addabsrefs $ProblemFileXml 2>$ProblemFileXml.errabs > $ProblemFileXml.abs; xsltproc --param const_links 1 --param default_target \\\'_self\\\'  --param linking \\\'l\\\' --param mizhtml \\\'\\\' --param selfext \\\'html\\\'  --param titles 1 --param colored 1 --param proof_links 1 $miz2html $ProblemFileXml.abs |tee $ProblemFile.html 2>$ProblemFileXml.errhtml`;

#    $result =~ s/([a-zA-Z0-9_-]+)\.html/$1\//g;
#    $result =~ s/(<script(.|[\n])*?<\/script>)/<script language=\"JavaScript\" src=\"tst.js\"><\/script>/;
#    writefile("tst.js", "$config{destdir}/$pname", $1);


#    system("rm -rf $TemporaryProblemDirectory");

    return $result;
}


1
