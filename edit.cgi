#!/usr/bin/perl -w

use strict;
use CGI;
use IO::Socket;
use File::Temp qw/ :mktemp  /;
use HTTP::Request::Common;
use LWP::Simple;

my $frontend_dir  = "/var/cache/git/";


my $query	  = new CGI;
my $git_project	  = $query->param('p');

# the file comes with relative path: mml/card_1.miz
my $input_file	  = $query->param('f');

my $frontend_repo = $frontend_dir . $git_project;

my $backend_repo_path = "";

print $query->header();

print $query->start_html(-title=>"Editing $input_file");

if (defined($git_project) && defined($input_file) && (-d $frontend_repo))
{
    chdir $frontend_repo;
    $backend_repo_path = `git config mwiki.backend`;
    chomp($backend_repo_path);
}
else
{
    print "The repository $git_project does not exist or input file not specified";
    print $query->end_html;
    exit;
}

if(!(defined $backend_repo_path) || (length($backend_repo_path) == 0))
{
    print "No backend repository for the project $git_project";
    print $query->end_html;
    exit 1;
}

my $backend_repo_file = $backend_repo_path . "/" . $input_file;

my $old_content = "";

if(-e $backend_repo_path)
{
    open(FILEHANDLE, $backend_repo_file) or die "$backend_repo_file not readable!";
    $old_content = do { local $/; <FILEHANDLE> };
    close(FILEHANDLE);
}
else
{
    $old_content = "New article comes here";
}

print<<END;
    <dl>
      <dd>
        <FORM METHOD="POST"  ACTION="commit.cgi?p=$git_project;f=$input_file" enctype="multipart/form-data">
         <br>
          <center>
          <table>
            <tr>
	      <TD> <INPUT TYPE="RADIO" NAME="ProblemSource" VALUE="Formula" ID="ProblemSourceRadioButton" CHECKED>Mizar article<br/>
		<textarea name="Formula" tabindex="3"  rows="40" cols="80" id="FORMULAEProblemTextBox">$old_content</textarea><TR VALIGN=TOP>
	      </td>
	      <TD> <INPUT TYPE="RADIO" NAME="ProblemSource" VALUE="UPLOAD">Local article file to upload<BR>
		<input type="file" name="UPLOADProblem"  size="20" /><TR VALIGN=TOP></TD>
<!--	      <TD> <INPUT TYPE="RADIO" NAME="ProblemSource" VALUE="URL" >URL to fetch article from<BR> -->
<!--		<input type="text" name="FormulaURL" tabindex="4"  size="80" /><TR VALIGN=TOP></TD> -->
<!--	      <TD> <INPUT TYPE="CHECKBOX" NAME="VocSource" VALUE="UPLOAD"> -->
<!--		Optional vocabulary file to upload (its name will be kept)<BR> -->
<!--		<input type="file" name="VocFile"  size="20" /></TD> -->
            </tr>
            <tr>
              <td align=right>
                <INPUT TYPE="submit" VALUE="Send">
                <INPUT TYPE="reset" VALUE="Clear">
              </td>
            </tr>
          </table>
          </center>
        </FORM>
      </dd>
    </dl>
END

print $query->end_html;

