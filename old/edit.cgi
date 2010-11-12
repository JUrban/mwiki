#!/usr/bin/perl -T -w

use strict;
use CGI;
use CGI::Pretty ":standard";
use IO::Socket;
use File::Temp qw/ :mktemp  /;
use HTTP::Request::Common;

my $frontend_dir  = "/var/cache/git/";

my $lgitwebcgi    = "http://mws.cs.ru.nl:1234/";

my $query	  = new CGI;
my $git_project	  = $query->param('p');

# the file comes with relative path: mml/card_1.miz
my $input_file	  = $query->param('f');

print $query->header();

print $query->start_html(-title=>"Editing $input_file",
			-head  => style(
{-type => 'text/css'},
'body {font-family: monospace; margin: 0px;}
.wikiactions ul { background-color: DarkSeaGreen ; color:blue; margin: 0; padding: 6px; list-style-type: none; border-bottom: 1px solid #000; }
.wikiactions li { display: inline; padding: .2em .4em; }'
                         )
);

sub pr_pad {
  my $str = shift;
  return ("[Editing] $str");
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
    print $query->end_html;
    exit;
}

# untaint the cgi params:
if(defined($git_project) && ($git_project =~ /^([a-zA-Z0-9_\-\.]+)$/))
{
    $git_project = $1;
}
else { pr_die("The repository name \"$git_project\" is not allowed"); }

if ($input_file =~ /^(mml\/[a-z0-9_]+\.miz)$/)
{
    $input_file = $1;
}
else { pr_die("The file name \"$input_file\" is not allowed"); }


my $frontend_repo = $frontend_dir . $git_project;
my $backend_repo_path = "";

if (-d $frontend_repo)
{
    chdir $frontend_repo;
    $backend_repo_path = `git config mwiki.backend`;
    chomp($backend_repo_path);
}
else
{
    pr_die "The repository \"$git_project\" does not exist";
}

if(!(defined $backend_repo_path) || (length($backend_repo_path) == 0))
{
    pr_die "No backend repository for the project $git_project";
}

my $backend_repo_file = $backend_repo_path . "/" . $input_file;

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
        <FORM METHOD="POST"  ACTION="commit.cgi" enctype="multipart/form-data">
         <br>
          <table>
            <tr>
	      <TD> <INPUT TYPE="RADIO" NAME="ProblemSource" VALUE="Formula" ID="ProblemSourceRadioButton" CHECKED>Edit article<br/>
		<textarea name="Formula" tabindex="3"  rows="40" cols="90" id="FORMULAEProblemTextBox">$old_content</textarea><TR VALIGN=TOP>
	      </td>
	      <TD> <INPUT TYPE="RADIO" NAME="ProblemSource" VALUE="UPLOAD">Article file to upload (not supported yet)<BR>
		<input type="file" name="UPLOADProblem"  size="20" /><TR VALIGN=TOP></TD>
                <input type="hidden" name="p" value="$git_project">
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

print $query->end_html;

