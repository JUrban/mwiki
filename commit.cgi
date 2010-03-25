#!/usr/bin/perl -T -w

use strict;
use CGI;
use CGI::Pretty ":standard";  # needed for the -style info
use IO::Socket;
use File::Temp qw/ :mktemp  /;

## TODO: we should think about how to allow customization
##       of the following variables.
##       If this lives in /lib/cgi-bin/mwiki, we might want to
##       pass at least the $htmldir as another cgi argument.
##       Others can stay fixed probably.

## NOTE: The htmldir is now a git config
##       variable of the backend and frontend.


# directory where frontends are stored
my $frontend_dir  = "/var/cache/git/";

# path to the git cgi
my $lgitwebcgi    = "http://mws.cs.ru.nl:1234/";

# path to the editing cgi - should be in the same dir
my $leditcgi    = "edit.cgi";

my $query	  = new CGI;
my $ProblemSource = $query->param('ProblemSource');
my $input_article	  = $query->param('Formula');
my $git_project	  = $query->param('p');

# the file comes with relative path: mml/card_1.miz
my $input_file	  = $query->param('f');

sub pr_pad {
  my $str = shift;
  return ("[Submitting] $str");
}

# I think there's a slicker way to do this, using output filters, but
# for now let's just do this as a subroutine.
sub pr_print {
  my $str = shift;
  chomp ($str); # in case it already had some extra whitespace at the end
  print (pr_pad ($str . "\n"));
}

sub pr_die
{
    pr_print(@_);
    print "</pre>";
    print $query->end_html;
    exit;
}

print $query->header();

print $query->start_html(-title=>"Submitting $input_file",
			-head  => style(
{-type => 'text/css'},
'body {font-family: monospace; margin: 0px;}
.wikiactions ul { background-color: DarkSeaGreen ; color:blue; margin: 0; padding: 6px; list-style-type: none; border-bottom: 1px solid #000; }
.wikiactions li { display: inline; padding: .2em .4em; }'
                         )
);

my $article_filename = "";
my $aname = "";


# untaint the cgi params:
if(defined($git_project) && ($git_project =~ /^([a-zA-Z0-9_\-\.]+)$/))
{
    $git_project = $1;
}
else { pr_die("The repository name \"$git_project\" is not allowed"); }

if ($input_file =~ /^(mml\/(([a-z0-9_]+)\.miz))$/)
{
    ($input_file, $article_filename, $aname) = ($1, $2, $3);
}
else { pr_die("The file name \"$input_file\" is not allowed"); }

my $frontend_repo = $frontend_dir . $git_project;

my $backend_repo_path = "";

# the directory with the htmlized wiki files (needed for index and other links)
my $htmldir       = "";

if (-d $frontend_repo)
{
    chdir $frontend_repo;
    $backend_repo_path = `git config mwiki.backend`;
    chomp($backend_repo_path);
    $htmldir = `git config mwiki.htmldir`;
    chomp($htmldir);
}
else
{
    pr_die "The repository \"$git_project\" does not exist.";
}



## only print the file links if the file is ok
## WARNING: This sub is using global vars $aname,$input_file,$git_project; don't move it!
##          It is a sub only because without it the scoping breaks.
sub printheader
{
    my $viewlinks = "";

    if(length($aname) > 0)
    {
	$viewlinks=<<VEND
         <li> <a href="$htmldir/$aname.html">View</a> </li>
         <li> <a href="$leditcgi?p=$git_project;f=$input_file">Edit</a> </li>
         <li> <a href="$lgitwebcgi?p=$git_project;a=history;f=$input_file">History</a> </li>
         <li> <a href="$lgitwebcgi?p=$git_project;a=blob_plain;f=$input_file">Raw</a> </li>
VEND
    }

    print<<END
 <div  class="wikiactions">
    <ul>
         $viewlinks
         <li> <a href="$htmldir/">Index</a> </li>
         <li> <a href="$lgitwebcgi?p=$git_project">Gitweb</a> </li>
    </ul>
</div>
<pre>
END
}

printheader();

if(!(defined $backend_repo_path) || (length($backend_repo_path) == 0))
{
    pr_die "No backend repository for the project $git_project";
}

if(!(defined $htmldir) || (length($htmldir) == 0))
{
    pr_die "No html directory for the project $git_project";
}

## TODO: stolen from pre-receive.in, this should be re-factored

# Ensure that all .miz files satisfy these conditions:
#
# 1 they are under the mml subdirectory
# 2 they are actually files, i.e., blobs in git terminology
# 3 their size is less than, say, one megabyte;
# 4 they have mode 644 ("should never happen", given condition #2)

unless (length($input_article) < 1000000) {
    pr_die ("Suspicious: the .miz file $input_file is bigger than one megabyte");
}

my $backend_repo_mml = $backend_repo_path . "mml";

# Copy the contents of the new file to the backend repo.
my $received_path = $backend_repo_mml . "/" . $article_filename;
open(PFH, ">$received_path") or pr_die "$received_path not writable";
printf(PFH "%s",$input_article);
close(PFH);
unless (-e $received_path)
{
    pr_die "We didn't output anything to $received_path";
}

## TODO: The current way of doing this is bad when the commit/add fails:
##    When we modify a file, and call git add, its current content is staged.
##    When the commit fails, and we copy over it the old version, the
##    modified version is still staged - this is bad. We need to undo
##    the staging too. Perhaps there is a pre-staging hook? Or it is
##    easy to undo the last staging?
##
##    Here is the answer: http://learn.github.com/p/undoing.html
##    we can use:
##    git reset HEAD
##    and
##    git checkout --
##    to unstage and unmodify
##
## NOTE: if we do things this way, we should not need the copying of
## the old files to tempdir.
##
## NOTE: we should also think of this in pre-commit

# All newly received mizar files are now in sitting in the backend
# repo.  Now we add them.
$ENV{GIT_DIR}
  = $backend_repo_path . "/" . ".git"; # GIT_DIR is set to "." by git
chdir $backend_repo_path;              # before executing this hook!
system ("git add $input_file 2>&1");
my $git_add_exit_code = ($? >> 8);
unless ($git_add_exit_code == 0) {
  pr_print ("Error adding the new mizar files to the backend repository:");
  pr_print ("The exit code was $git_add_exit_code");

  system ("git reset HEAD 2>&1");
  system ("git checkout -- 2>&1");

  pr_die "";
}

# We've successful added new files to the repo -- let's commit!
$ENV{GIT_DIR} = $backend_repo_path . "/" . ".git"; # just to be safe
my $git_commit_output 
  = system ("git commit -m 'Web commit' 2>&1");
my $git_commit_exit_code = ($? >> 8);
unless ($git_commit_exit_code == 0) {
  pr_print ("Error commiting to the backend repository:");
  pr_print ("The exit code was $git_commit_exit_code");

  system ("git reset HEAD 2>&1");
  system ("git checkout -- 2>&1");

  pr_die "";
}

# If we made it this far, then we deserve a break.
exit 0;
