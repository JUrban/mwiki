#!/usr/bin/perl
# CoqDoc and Coq plugin
# based on the WikiText plugin.
package IkiWiki::Plugin::coq;

use warnings;
use strict;
use IkiWiki 3.00;
use File::Temp qw/ :mktemp  /;
my $TemporaryDirectory = "/tmp";
my $TemporaryProblemDirectory = "$TemporaryDirectory/coq_$$";
my $PidNr = $$;


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
	my $pname = $params{page}
	my $content = $params{content};

#	eval q{use CoqDoc};
#	return $content if $@;


	return coqdoc($pname, $content);
}

sub coqdoc {
    my ($pname, $content) = @_;
    my $ProblemFile = $pname . '.v';
    chdir $TemporaryProblemDirectory;

    open(PFH, ">$ProblemFile") or die "$ProblemFile not writable";
    printf(PFH "%s",$content);
    close(PFH);
    my $result = `coqdoc --no-index --stdout $ProblemFile`;
    return $result;
}


1
