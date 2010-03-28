#!/usr/bin/perl -T -w

use strict;
use CGI;
use CGI::Pretty ":standard";
use IO::Socket;
use HTTP::Request::Common;

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

# the git binary - need absolute path - we run in taint mode
my $git           = "/usr/bin/git";

my $query	  = new CGI;

# the file comes with relative path: mml/card_1.miz
my $input_file	  = $query->param('f');
my $action	  = $query->param('a');
my $git_project	  = $query->param('p');

# these exist only when commiting
my $ProblemSource = $query->param('ProblemSource');
my $input_article = $query->param('Formula');

# this is required to untaint backticks
$ENV{"PATH"} = "";


print $query->header();
print $query->start_html(-title=>"Processing $input_file",
			-head  => style(
{-type => 'text/css'},
'body {font-family: monospace; margin: 0px;}
.wikiactions ul { background-color: DarkSeaGreen ; color:blue; margin: 0; padding: 6px; list-style-type: none; border-bottom: 1px solid #000; }
.wikiactions li { display: inline; padding: .2em .4em; }'
                         )
);

sub pr_pad {
  my $str = shift;
  return ("[Mwiki] $str");
}

sub pr_print {
  my $str = shift;
  chomp ($str); # in case it already had some extra whitespace at the end
  print (pr_pad ($str . "\n"));
}

sub pr_die
{
    pr_print(@_);
    print $query->end_html;
    exit;
}

my $article_filename = "";
my $aname = "";

# untaint the cgi params:
if(defined($git_project) && ($git_project =~ /^([a-zA-Z0-9_\-\.]+)$/))
{
    $git_project = $1;
}
else { pr_die("The repository name \"$git_project\" is not allowed"); }

if ((defined $input_file) && ($input_file =~ /^(mml\/(([a-z0-9_]+)\.miz))$/))
{
    ($input_file, $article_filename, $aname) = ($1, $2, $3);
}
else { pr_die("The file name \"$input_file\" is not allowed"); }

if ((defined $action) && (($action =~ /^(edit)$/) || ($action =~ /^(commit)$/)))
{
    $action = $1;
}
else { pr_die("Unknown action \"$action\"."); }


my $frontend_repo = $frontend_dir . $git_project;
my $backend_repo_path = "";

# the directory with the htmlized wiki files (needed for index and other links)
my $htmldir       = "";

# the wikihost, and the true cgi path
my $wikihost= "";

if (-d $frontend_repo)
{
    chdir $frontend_repo;
    $backend_repo_path = `$git config mwiki.backend`;
    chomp($backend_repo_path);
    $htmldir = `$git config mwiki.htmldir`;
    chomp($htmldir);
    $wikihost=`$git config mwiki.wikihost`;
    chomp($wikihost);
    $lgitwebcgi="http://$wikihost:1234/";
}
else
{
    pr_die "The repository \"$git_project\" does not exist";
}

if(!(defined $backend_repo_path) || (length($backend_repo_path) == 0))
{
    pr_die "No backend repository for the project $git_project";
}

# untaint $backend_repo_path - we trust it, it is in our repo

if($backend_repo_path =~ /^(.*)$/) { $backend_repo_path = $1; }


if(!(defined $htmldir) || (length($htmldir) == 0))
{
    pr_die "No html directory for the project $git_project";
}


my $backend_repo_file = $backend_repo_path . "/" . $input_file;

## only print the file links if the file is ok
## WARNING: This sub is using global vars $aname,$input_file,$git_project; don't move it!
##          It is a sub only because without it the scoping breaks.
sub printcommitheader
{
    my $viewlinks = "";

    if(length($aname) > 0)
    {
	$viewlinks=<<VEND
         <li> <a href="$htmldir/$aname.html">View</a> </li>
         <li> <a href="?p=$git_project;a=edit;f=$input_file">Edit</a> </li>
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

## the action for committing
if($action eq "commit")
{
    printcommitheader();

    unless (length($input_article) < 1000000) 
    {
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
    pr_print ("Adding $input_file to $backend_repo_path");
    system ("$git add $input_file 2>&1");
    my $git_add_exit_code = ($? >> 8);
    unless ($git_add_exit_code == 0) 
    {
	pr_print ("Error adding the new mizar files to the backend repository:");
	pr_print ("The exit code was $git_add_exit_code");

	system ("$git reset --hard 2>&1");

	pr_die "";
    }

# We've successful added new files to the repo -- let's commit!
#    $ENV{GIT_DIR} = $backend_repo_path . "/" . ".git"; # just to be safe
    chdir $backend_repo_path;              # before executing this hook!
    my $git_commit_output 
	= system ("$git commit -m 'Web commit' 2>&1");
    my $git_commit_exit_code = ($? >> 8);
    unless ($git_commit_exit_code == 0) 
    {
	pr_print ("Error commiting to the backend repository:");
	pr_print ("The exit code was $git_commit_exit_code");

	system ("$git reset --hard 2>&1");

	pr_die "";
    }

}

## the action for editing
if($action eq "edit")
{

    my $old_content = "";

    if(-e $backend_repo_path)
    {
	open(FILEHANDLE, $backend_repo_file) or pr_die "$backend_repo_file not readable!";
	$old_content = do { local $/; <FILEHANDLE> };
	close(FILEHANDLE);
    }
    else
    {
	$old_content = "New article comes here";
    }

    print<<END;
 <div  class="wikiactions">
    <ul>
         <li> <a href="javascript:javascript:history.go(-1)">Cancel</a> </li>
         <li> <a href="$lgitwebcgi?p=$git_project;a=history;f=$input_file">History</a> </li>
         <li> <a href="$lgitwebcgi?p=$git_project;a=blob_plain;f=$input_file">Raw</a> </li>
         <li> <a href="$lgitwebcgi?p=$git_project">Gitweb</a> </li>
    </ul>
</div>
    <dl>
      <dd>
        <FORM METHOD="POST"  ACTION="mwiki.cgi" enctype="multipart/form-data">
         <br>
          <table>
            <tr>
	      <TD> <INPUT TYPE="RADIO" NAME="ProblemSource" VALUE="Formula" ID="ProblemSourceRadioButton" CHECKED>Edit article<br/>
		<textarea name="Formula" tabindex="3"  rows="40" cols="90" id="FORMULAEProblemTextBox">$old_content</textarea><TR VALIGN=TOP>
	      </td>
	      <TD> <INPUT TYPE="RADIO" NAME="ProblemSource" VALUE="UPLOAD">Article file to upload (not supported yet)<BR>
		<input type="file" name="UPLOADProblem"  size="20" /><TR VALIGN=TOP></TD>
                <input type="hidden" name="p" value="$git_project">
                <input type="hidden" name="a" value="commit">
                <input type="hidden" name="f" value="$input_file">
<!--	      <TD> <INPUT TYPE="RADIO" NAME="ProblemSource" VALUE="URL" >URL to fetch article from<BR> -->
<!--		<input type="text" name="FormulaURL" tabindex="4"  size="80" /><TR VALIGN=TOP></TD> -->
<!--	      <TD> <INPUT TYPE="CHECKBOX" NAME="VocSource" VALUE="UPLOAD"> -->
<!--		Optional vocabulary file to upload (its name will be kept)<BR> -->
<!--		<input type="file" name="VocFile"  size="20" /></TD> -->
            </tr>
            <tr>
              <td align=right>
                <INPUT TYPE="submit" VALUE="Submit">
                <INPUT TYPE="reset" VALUE="Reset">
              </td>
            </tr>
          </table>
        </FORM>
      </dd>
    </dl>
END

}

print $query->end_html;
