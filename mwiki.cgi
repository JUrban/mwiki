#!/usr/bin/perl  -w

use strict;
use CGI;
use CGI::Pretty ":standard";
use IO::Socket;
use HTTP::Request::Common;
use File::Copy;


## TODO: we should think about how to allow customization
##       of the following variables.
##       If this lives in /lib/cgi-bin/mwiki, we might want to
##       pass at least the $htmldir as another cgi argument.
##       Others can stay fixed probably.

## NOTE: The htmldir is now a git config
##       variable of the backend and frontend.

# path to the git cgi
my $lgitwebcgi    = "http://mws.cs.ru.nl:1234/";

# the git binary - need absolute path - we run in taint mode
my $git           = "/usr/bin/git";

# ###TODO: make these changable by sed-ing
# the MWUSER - everything is now in his gitolite, this should be in sync with Makefile.smallinstall
my $MWUSER 	  = "@@MWUSER@@";

# the REPO_NAME - sync with Makefile.smallinstall, all gitweb repos dwell bellow this dir
my $REPO_NAME	  = "@@REPO_NAME@@";

# do we use the btrfs cloning?- sync with smallinstall
my $MW_BTRFS	  = "@@MW_BTRFS@@";

# gitweb

my $GITWEB_ROOT   = "@@GITWEB_ROOT@@";


# directory where frontends are stored
my $GITWEB_REPOS  = "$GITWEB_ROOT/$REPO_NAME/";

my $MWUSER_HOME	  = "/home/$MWUSER";
my $REPOS_BASE    = "$MWUSER_HOME/clones";
my $BARE_REPOS    = "$MWUSER_HOME/repositories";
my $MWADMIN_DIR   = "$MWUSER_HOME/mwadmin";
my $PUBLIC_REPO   = "$REPOS_BASE/public";
my $BARE_PUBLIC_REPO = "$BARE_REPOS/public.git";


my $query	  = new CGI;

# the file comes with relative path: mml/card_1.miz
my $input_file	  = $query->param('f');
my $action	  = $query->param('a');

# the edited subsection, format: t1_23_45 (theorem 1, beginning line 23, end line 45)
my $section	  = $query->param('s');
my $git_project	  = $query->param('p');

# these exist only when commiting
my $ProblemSource = $query->param('ProblemSource');
my $input_article = $query->param('Formula');
my $message       = $query->param('Message');

# registering
my $username      = $query->param('username');
my $passwd        = $query->param('password');
my $pubkey        = $query->param('pubkey');

# this is required to untaint backticks
# $ENV{"PATH"} = "";

my $titleaction="Unknown wiki action";

if (defined $action) 
{
if (($action =~ /^(edit)$/) || ($action =~ /^(commit)$/)
          || ($action =~ /^(history)$/) || ($action =~ /^(dependencies)$/))
{
    $titleaction = ucfirst ("$1 of $input_file");
}
elsif ($action =~ /^(blob_plain)$/)
{
    $titleaction = "Source of $input_file";
}
elsif  ($action =~ /^(gitweb)$/)
{
    $titleaction = "Project history";
}
elsif  ($action =~ /^(users)$/)
{
    $titleaction = "Project users";
}

}

print $query->header();
print $query->start_html(-title=>"$titleaction",
			 -dtd=>'-//W3C//DTD HTML 3.2//EN',
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

sub pr_die_unlock
{
    pr_print(@_);
    print $query->end_html;
    unlockwiki();
    exit;
}

sub clone_full_dirs 
{
    my ($origin,$clone) = @_;
    my ($clone_output, $clone_exit_code);

    if ($MW_BTRFS == 1)
    {
	$clone_output = `btrfs subvolume snapshot  $origin $clone 2>&1`;
    }
    else
    {
	$clone_output = `rsync -a --del $origin/ $clone 2>&1`;
    }

    $clone_exit_code = ($? >> 8);
    unless ($clone_exit_code == 0) {
    pr_print ("cloning was unsuccessful from $origin to $clone : $!");
    pr_print ("It's output was:");
    pr_print ("$clone_output\n");
    pr_print ("We cannot continue.");
    exit 1;
  }
}

# assumes the right directory
sub set_git_var
{
    my ($key, $value) = @_;
    system("git config  $key $value");
}

# assumes the right directory
sub set_git_vars
{
    my $vars = shift;
    foreach my $key (keys %$vars)
    {
	set_git_var($key, $vars->{$key});
    }
}



my $aname = "";

# untaint the cgi params:
if(defined($git_project) && ($git_project =~ /^([a-zA-Z0-9_\-\.]+)$/))
{
    $git_project = $1;
}
else { pr_die("The repository name \"$git_project\" is not allowed"); }

if ((defined $action) 
    && (($action =~ /^(edit)$/) || ($action =~ /^(commit)$/) 
	|| ($action =~ /^(history)$/) || ($action =~ /^(users)$/)
	|| ($action =~ /^(blob_plain)$/) || ($action =~ /^(gitweb)$/)
	|| ($action =~ /^(dependencies)$/) || ($action =~ /^(register)$/)))
{
    $action = $1;
}
else { pr_die("Unknown action \"$action\"."); }

my $mizar_article_ext = 'miz';
my $coq_article_ext = 'v';
my $article_ext = $mizar_article_ext;
my $article_regexp = '\.$article_ext\$';

# Other file extensions that we have to allow.
my $mizar_special_ext = 'voc';
my $special_ext = $mizar_special_ext;
my $special_regexp = '\.$special_ext\$';

my $this_ext = "";

if ((defined $input_file) && ($input_file =~ /^((mml|dict)\/([a-z0-9_]+)[.]($article_ext|$special_ext))$/))
{
    ($aname, $this_ext) = ($3, $4);
}
elsif ($action =~ /^(gitweb)$/) { $aname=""; }
 elsif ($action =~ /^(register)$/) { } # do nothing, but for god's sake, don't go to the next clause!
else { pr_die("The file name \"$input_file\" is not allowed"); }


my $gitweb_repo_path = $GITWEB_REPOS . $git_project;
my $backend_repo_path = "";

# the directory with the htmlized wiki files (needed for index and other links)
my $htmldir       = "";

# the wikihost, and the true cgi path
my $wikihost= "";


# ###TODO: reading these vars from the config is now probably unnecessary
if (-d $gitweb_repo_path)
{
    chdir $gitweb_repo_path;
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
    pr_die "The repository \"$git_project\" does not exist: $gitweb_repo_path";
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

my $sectparam = (defined $section)? ";s=$section" : "";

## only print the file links if the file is ok - the length of $aname is 0 if only gitweb
## WARNING: This sub is using global vars $aname,$input_file,$git_project; don't move it!
##          It is a sub only because without it the scoping breaks.
sub printheader
{
    my $viewlinks = "";

    if(length($aname) > 0)
    {
	if($this_ext eq $article_ext)
	{
	$viewlinks=<<VEND
         <li> <a href="$htmldir/$aname.html">View</a> </li>
         <li> <a href="?p=$git_project;a=edit;f=$input_file">Edit</a> </li>
         <li> <a href="?p=$git_project;a=history;f=$input_file">History</a> </li>
         <li> <a href="?p=$git_project;a=blob_plain;f=$input_file">Raw</a> </li>
         <li> <a href="?p=$git_project;a=dependencies;f=$input_file$sectparam">Dependencies</a> </li>
VEND
	}
	else  # no htmlization - present as raw
	{
	    	$viewlinks=<<REND
         <li> <a href="?p=$git_project;a=blob_plain;f=$input_file">View</a> </li>
         <li> <a href="?p=$git_project;a=edit;f=$input_file">Edit</a> </li>
         <li> <a href="?p=$git_project;a=history;f=$input_file">History</a> </li>
         <li> <a href="?p=$git_project;a=blob_plain;f=$input_file">Raw</a> </li>
REND
	}
    }

    print<<END
 <div  class="wikiactions">
    <ul>
         $viewlinks
         <li> <a href="$htmldir/">Index</a> </li>
         <li> <a href="?p=$git_project;a=gitweb">Gitweb</a> </li>
         <li> <a href="?p=$git_project;a=register">Register</a> </li>
         <li> <a href="?p=$git_project;a=users">Users</a> </li>
    </ul>
</div>
END
}

sub print_iframe
{
    my $url = shift;
    print<<END1
<iframe src ="$url" width="90%" height="90%" style="margin:10px" frameborder="1">
<p>Your user agent does not support iframes or is currently configured
  not to display iframes. However, you may visit
  <A href="$url">the related document.</A></p>
</iframe>
END1

}

## the action for gitweb
## this has to exit here before we start working with $input_file
if($action eq "gitweb")
{
    printheader();
    print_iframe("$lgitwebcgi?p=$REPO_NAME/$git_project");
    print $query->end_html;
    exit;
}

my $backend_repo_file = $backend_repo_path . "/" . $input_file;

my $wikilock;

# locking taken from ikiwiki
sub lockwiki () {
	# Take an exclusive lock on the wiki to prevent multiple concurrent
	# run issues. The lock will be dropped on program exit.
	open($wikilock, '>', $backend_repo_path . ".wikilock") ||
	    pr_die ("The wiki cannot write to the lock file $backend_repo_path.wikilock: $!");
	if (! flock($wikilock, 2|4)) { # LOCK_EX | LOCK_NB
		pr_die("The wiki is being used for another commit, try again in a minute: failed to get lock");
	}
	return 1;
}

sub unlockwiki () {
	return close($wikilock) if $wikilock;
	return;
}



## the action for committing
if($action eq "commit")
{
    printheader();

    print "<pre>";


    if(defined($message) && ($message =~ /^[^']+$/) && ($message =~ /^\s*(\S(\s|\S)*)\s*$/))
    {
	$message = $1;
    }
    else { pr_die("Bad commit message: \"$message\" "); }

    unless (length($input_article) < 1000000) 
    {
	pr_die ("Suspicious: the file $input_file is bigger than one megabyte");
    }

    # remove the dos stuff
    $input_article =~ s/\r//g;


    if ((defined $section) && ($section=~m/t(\d+)_(\d+)_(\d+)/))
    {
	open(FILEHANDLE, $backend_repo_file) or pr_die "$backend_repo_file not readable!";
	my ($nr, $l1, $l2) = ($1, $2, $3);
	my @lines = ();
	while($_=<FILEHANDLE>) { push(@lines, $_); };
	close(FILEHANDLE);
	$input_article =  join("", @lines[0..$l1-1]) . $input_article . join("", @lines[$l2..$#lines]);
    }


    chdir $backend_repo_path;              # before locking executing this hook!

    lockwiki();

    # Copy the contents of the new file to the backend repo.
    ($input_file =~ /^(mml|dict)\/[a-z0-9_]+[.]($article_ext|$special_ext)$/) or
	pr_die("Wrong file name: $input_file");
    my $possibly_new_dir_path = $1;
    `mkdir -p $backend_repo_path$possibly_new_dir_path`;
    my $received_path = $backend_repo_path . $input_file;
    open(PFH, ">$received_path") or pr_die_unlock "$received_path not writable";
    printf(PFH "%s",$input_article);
    close(PFH);
    unless (-e $received_path)
    {
	pr_die_unlock"We didn't output anything to $received_path";
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
#    $ENV{GIT_DIR}
#	= $backend_repo_path . "/" . ".git"; # GIT_DIR is set to "." by git
    pr_print ("Adding $input_file to $backend_repo_path");
    system ("$git add $input_file 2>&1");
    my $git_add_exit_code = ($? >> 8);
    unless ($git_add_exit_code == 0) 
    {
	pr_print ("Error adding the new files to the backend repository:");
	pr_print ("The exit code was $git_add_exit_code");

	system ("$git reset --hard 2>&1");

	pr_die_unlock "";
    }

# We've successful added new files to the repo -- let's commit!
#    $ENV{GIT_DIR} = $backend_repo_path . "/" . ".git"; # just to be safe
    chdir $backend_repo_path;              # before executing this hook!
    my $git_commit_output 
	= system ("export MW_SECTION=$section && export MW_FILE=$input_file && $git commit -m '$message' 2>&1");
    my $git_commit_exit_code = ($? >> 8);
    unless ($git_commit_exit_code == 0) 
    {
	pr_print ("Error commiting to the backend repository: $git_commit_output");
	pr_print ("The exit code was $git_commit_exit_code");

	system ("$git reset --hard 2>&1");

	pr_die_unlock "";
    }

    # ###TODO: remove the reliance on the giweb repo symlinks
    # now push to frontend, disabling pre-receive
    pr_print ("Pushing the commit to frontend");
    my $mv_out = system("/bin/mv -f $gitweb_repo_path/hooks/pre-receive $gitweb_repo_path/hooks/pre-receive.old 2>&1");
    my $git_push_output 
	= system("$git push frontend HEAD 2>&1");
    my $git_push_exit_code = ($? >> 8);
    unless ($git_push_exit_code == 0) 
    {
	pr_print ("Error pushing to the frontend repository: $git_push_output :: $mv_out");
	system("/bin/cp $gitweb_repo_path/hooks/pre-receive.old $gitweb_repo_path/hooks/pre-receive");
	pr_die_unlock ("The exit code was $git_push_exit_code");

    }
    system("/bin/cp $gitweb_repo_path/hooks/pre-receive.old $gitweb_repo_path/hooks/pre-receive");
    pr_print ("All OK!");
    unlockwiki();
}

## the action for raw
if($action eq "blob_plain")
{
    printheader();
    print_iframe("$lgitwebcgi?p=$REPO_NAME/$git_project;a=blob_plain;f=$input_file");
}

## the action for history
if($action eq "history")
{
    printheader();
    print_iframe("$lgitwebcgi?p=$REPO_NAME/$git_project;a=history;f=$input_file");
}

## the action for dependencies
if($action eq "dependencies")
{
    printheader();

    ($input_file =~ /^mml\/([a-z0-9_]+)[.]$article_ext$/) or
	pr_die("No dependencies for: $input_file $section");

    my $mwfile = $1;
    my $do_section=0;


    if ((defined $section) && ($section=~m/t(\d+)_(\d+)_(\d+)/))
    {
	$titleaction = $titleaction . ' Th' . uc($1);

	# add the file part
	$section = 't' . $1 . '_' . $mwfile;
	$do_section = 1;

    }

    print '<div class=index><div class=indexheading>';
    print '<h1>', $titleaction, '</h1></div><hr/><p>';

    chdir $backend_repo_path . 'mml';          

    my $dollar = '$';
    my @section_deps = ();

    if ($do_section == 1)
    {
	@section_deps =
	    `tail -n +2 deps | sed -e 's/$dollar/.fdeps/' | xargs egrep -l ' $section( |$dollar)' | sed -e 's/.fdeps$dollar/.hdr/'`;
    }
    else
    {
	@section_deps = `grep ' $mwfile$dollar' deps0 | sed -e 's/ .*/.hdr/'`;
    }

    chomp @section_deps;

    my $depsstring = join(' ', @section_deps); 

    print `$backend_repo_path/.perl/mkmmlindex.pl -d1 -H $htmldir/ $depsstring`;

    print '</dd></dl></div><hr/>';

}



my $voc_template="K\n";

my $article_template=<<AEND
:: Article Title
::  by Article Author
::
::
:: Copyright (c) Article Author

environ

 vocabularies TARSKI, XBOOLE_0;
 notations TARSKI, XBOOLE_0;
 constructors TARSKI, XBOOLE_0;
 definitions TARSKI, XBOOLE_0;
 theorems TARSKI, XBOOLE_0, XBOOLE_1;
 schemes XBOOLE_0;

begin

reserve x,x1,x2 for set;

theorem Foo: x=x;
AEND
;

## the action for editing
if($action eq "edit")
{

    my $old_content = "";

    if(-e $backend_repo_file)
    {
	open(FILEHANDLE, $backend_repo_file) or pr_die "$backend_repo_file not readable!";
	if ((defined $section) && ($section=~m/t(\d+)_(\d+)_(\d+)/))
	{
	    my ($nr, $l1, $l2) = ($1, $2, $3);
	    my @lines = ();
	    while($_=<FILEHANDLE>) { push(@lines, $_); };
	    my $l0 = $l1;
	    my $th = $lines[$l0];
	    while(!($th =~ m/\btheorem\b/)) {$th = $lines[$l0--];}
	    $old_content = join("", @lines[++$l0 .. $l2-1]);
	    $section = "t$nr" . '_' . $l0 . '_' . $l2;  # so that we don't seek again on commit
	}
	else { $old_content = do { local $/; <FILEHANDLE> }; }
	close(FILEHANDLE);
    }
    elsif($this_ext eq $article_ext)
    {
	$old_content = $article_template;
    }
    else
    {
	$old_content = $voc_template;
    }

    print<<END;
 <div class="wikiactions">
  <ul>
     <li><a href="javascript:javascript:history.go(-1)">Cancel</a></li>
     <li><a href="?p=$git_project;a=history;f=$input_file">History</a> </li>
     <li><a href="?p=$git_project;a=blob_plain;f=$input_file">Raw</a> </li>
     <li><a href="?p=$git_project;a=dependencies;f=$input_file$sectparam">Dependencies</a> </li>
     <li><a href="$htmldir/">Index</a> </li>
     <li><a href="?p=$git_project;a=gitweb">Gitweb</a> </li>
     <li><a href="?p=$git_project;a=register">Register</a> </li>
     <li><a href="?p=$git_project;a=users">Users</a> </li>
  </ul>
</div>
<dl>
  <dd>
    <form method="post" action="mwiki.cgi" enctype="multipart/form-data">
    <br>
    <table>
      <tr>
        <td>
          <input type="radio" name="ProblemSource" value="Formula" id="ProblemSourceRadioButton" checked>Edit article<br/>
          <textarea name="Formula" tabindex="3"  rows="35" cols="90" id="FORMULAEProblemTextBox">$old_content</textarea>
        <tr valign="top">
        </td>
         <!--      <td>
         <!-- <input type="radio" name="ProblemSource" value="UPLOAD">Article file to upload (not supported yet) -->
         <!-- <br/> -->
         <!-- <input type="file" name="UPLOADProblem"  size="30" />  -->
         <!--  <tr valign="top">  -->
         <!-- </td> -->
          <input type="hidden" name="p" value="$git_project">
          <input type="hidden" name="a" value="commit">
          <input type="hidden" name="f" value="$input_file">
          <input type="hidden" name="s" value="$section">
        <!--	<td> <input type="radio" name="ProblemSource" value="URL" >URL to fetch article from<br> -->
        <!--	<input type="text" name="FormulaURL" tabindex="4"  size="80" /><TR VALIGN=TOP></TD> -->
        <!-- <td> <input type="checkbox" name="VocSource" value="UPLOAD"> -->
        <!--	Optional vocabulary file to upload (its name will be kept)<BR> -->
        <!--	<input type="file" name="VocFile"  size="20" /></TD> -->
      </tr>
      <tr>
              <td align=top>
	      Commit message (mandatory):<br>
                <textarea name="Message" tabindex="3"  rows="2" cols="40" id="MessageTextBox"></textarea>
              </td>
            </tr>
      <tr>
        <td align=right>
          <input type="submit" value="Submit">
          <input type="reset" value="Reset">
         </td>
       </tr>
     </table>
   </form>
 </dd>
 </dl>
END

}

# "Register" with us by giving us your RSA public key.

my $registration_form = <<REG_FORM;
<form method="post" action="mwiki.cgi" enctype="multipart/form-data">
Desired username: <input type="text" size="10" name="username" />
Desired password: <input type="text" size="10" name="password" />
<br />
Your RSA public key: <input type="textarea" size="20" name="pubkey" />
<input type="submit" value="Register" />
<input type="reset" value="Reset" />
<input type="hidden" name="p" value="$git_project">
<input type="hidden" name="a" value="register">
</form>
REG_FORM

my $bad_username = <<BAD_USERNAME;
<p>
Your username, '$username', is invalid; it must be between 1 and 25 alphanumeric characters (dash '-' and underscore '_' are allowed).  Please go back and try again.</p>
BAD_USERNAME

my $gitolite_admin_dir =  $MWUSER_HOME . '/gitolite-admin';
my $gitolite_key_dir = $gitolite_admin_dir . '/keydir';
my $gitolite_conf_dir = $gitolite_admin_dir . '/conf';
my $gitolite_user_conf_file = $gitolite_conf_dir . '/users.conf';
my $gitolite_user_list_file = $MWADMIN_DIR . '/gitolite-users';

my $pre_receive_file = $MWADMIN_DIR  . '/pre-receive.in';

sub print_successful_registration_message {
  my $username = shift;
  print <<SUCCESS;

<p>
Success!  You have registered with us.  We have made a new
repository for you whose contents reflect the current state of the
public wiki.  You can obtain a local copy of the repository by issuing
the command on your machine:</p>

<blockquote>
git clone $MWUSER\@$wikihost:$username
</blockquote>

<p>
This will create a new directory called '$username' in whatever
directory you were in when you issued the git clone command. If you
would like to store the repository under a different name (e.g., 'my-mizar-wiki-repo'), issue the
command</p>

<blockquote>
git clone $MWUSER\@$wikihost:$username my-mizar-wiki-repo
</blockquote>

<p>
If this command does not work for you, please contact us.</p>

<p>
Feel free to make whatever changes you would like to your local
copy of your repository.  To upload your changes to our server, issue the commands:</p>

<blockquote>
git add .<br/>
git commit -m "(fill in some clever summary of what you did here)"<br/>
git push
</blockquote>

<p>
Your work will then be uploaded to the server.  Again, if any of these commands fail, please get in touch with us.</p>

<p align="center">
Happy Mizaring!</p>

SUCCESS
}

if($action eq "register") 
{
  if (defined ($username) && defined ($passwd) && defined ($pubkey)) {
    if ($username =~ /[a-z0-9A-Z-_]{1,25}/) {
      lockwiki ();
      # first, add the user to the list of all users
      # sanity
      unless (-r $gitolite_user_conf_file) {
	pr_die_unlock ("<p>Uh oh: the gitolite user configuration file at '$gitolite_user_conf_file' is unreadable.  Please complain loudly to the administrators.</p>");
      }
      unless (-w $gitolite_user_conf_file) {
	pr_die_unlock ("<p>Uh oh: the gitolite user configuration file at '$gitolite_user_conf_file' is unwritable.  Please complain loudly to the administrators.</p>");
      }
      open (USER_CONF_FILE, '>>', $gitolite_user_conf_file)
	or pr_die_unlock ("<p>Uh oh: something went wrong while opening the gitolite user configuration file '$gitolite_user_conf_file' to register '$username':</p><blockquote>" . escapeHTML ($!) . "</blockquote> <p>Please complain loudly to the administrators.</p>");
      print USER_CONF_FILE <<USER_CONFIG;
\@users = $username
repo $username
   R   = \@all
   RW+ = $username $MWUSER

USER_CONFIG
      close USER_CONF_FILE
	or pr_die_unlock ("Something went wrong closing the output filehandle for the user configuration file!");

      # copy the given public key to the keydir
      my $user_key_file = $gitolite_key_dir . '/' . "$username" . '.pub';
      open (USER_KEY_FILE, '>', $user_key_file) 
	or pr_die_unlock ("<p>Uh oh: something went wrong while opening the an output filehandle at '$user_key_file':</p><blockquote>" . escapeHTML ($!) . "</blockquote> <p>Please complain loudly to the administrators.</p>");
      print USER_KEY_FILE ("$pubkey\n");
      close (USER_KEY_FILE)
	or pr_die_unlock ("<p>Uh oh: something went wrong when closing the output filehandle at '$user_key_file':</p><blockquote>" . escapeHTML ($!) . "</blockquote><p>Please complain loudly to the administrators.</p>");
      chdir $gitolite_admin_dir;
      # add the changed files (we should probably lock things here, if not earlier)
      my $git_add_exit_code = system ('git', 'add', '.');
      if ($git_add_exit_code != 0) {
	my $git_add_error_message = $git_add_exit_code >> 8;
	pr_die_unlock ("<p>Uh oh: something went wrong staging the modified files in the gitolite admin repo:</p><blockquote>" . escapeHTML ($git_add_error_message) . "</blockquote><p>Please complain loudly to the administrators.</p>");
      }
      # commit these changes to the gitolite admin repo
      my $git_commit_exit_code = system ('git', 'commit', '--quiet', '-a', '-m', "Added public key '$pubkey' for user '$username'");
      if ($git_commit_exit_code != 0) {
	my $git_commit_error_message = $git_commit_exit_code >> 8;
	pr_die_unlock ("<p>Uh oh: something went wrong commiting the changes to the gitolite admin repo:</p><blockqute>" . escapeHTML ($git_commit_error_message) . "</blockquote><p>Please complain loudly to the administrators.");
      }
      # push the changes to the real gitolite admin repo
      my $git_push_adm_exit_code = system ('git', 'push', '--quiet');
      if ($git_push_adm_exit_code != 0) {
	my $git_push_adm_error_message = $git_push_adm_exit_code >> 8;
	pr_die_unlock ("<p>Uh oh: something went wrong pushing the changes we just made to to the gitolite admin repo:</p><blockqute>" . escapeHTML ($git_push_adm_error_message) . "</blockquote><p>Please complain loudly to the administrators.");
      }

      ### TODO: the btrfs/rsync stuff goes here

      # first do filesystem clone of the backend public repo 

      my $user_backend_repo = "$REPOS_BASE/$username";

      clone_full_dirs($PUBLIC_REPO, $user_backend_repo);

      # fix .git/config
      
      # TODO: set other vars here like makejobs, etc

      my %mw_git_backend_vars = 
	  ("user.name" => $username,
	   "user.email" => "$username\@none.none",
	   "mwiki.wikihost" => $wikihost,
	   "mwiki.htmldir" => "http://$wikihost/$REPO_NAME/$username");

      chdir  $user_backend_repo;
      set_git_vars(\%mw_git_backend_vars);

      # then push to the bare repo for the newly registered user

      my $bare_user_repo_ssh = "$MWUSER\@$wikihost:$username";

      my $git_push_exit_code =
	  system ('git', 'push', '--all', $bare_user_repo_ssh);
      if ($git_push_exit_code != 0) {
	my $git_push_error_message = $git_push_exit_code >> 8;
	pr_die_unlock ("<p>Uh oh: something went wrong while pushing the repository for '$username':$bare_user_repo_ssh</p><blockquote>" .  escapeHTML ($git_push_error_message) . "</blockquote> <p>Please complain loudly to the administrators.</p>");
      }

      # this now exists
      my $user_gitolite_bare_repo = "$BARE_REPOS/$username.git";

      # remove the copied frontend config, set the new
      system("git remote rm frontend");
      system("git remote add frontend $bare_user_repo_ssh");



      my %mw_git_bare_vars = 
      ("core.sharedRepository" => "true",
       "daemon.receivepack" => "true",
       "mwiki.backend" => "$user_backend_repo/",
       "mwiki.wikihost" => $wikihost,
       "mwiki.htmldir" => "http://$wikihost/$REPO_NAME/$username");

      chdir  $user_gitolite_bare_repo;
      set_git_vars(\%mw_git_bare_vars);


      system("touch $user_gitolite_bare_repo/git-daemon-export-ok");

      # install hooks: pre-receive, post-update

      foreach my $hookfile ("pre-receive", "post-update")
      {
	  open(H,"$MWADMIN_DIR/$hookfile.in") or pr_die_unlock ("Hook not readable: $MWADMIN_DIR/$hookfile.in");
	  open(H1,">$user_gitolite_bare_repo/hooks/$hookfile") 
	      or pr_die_unlock ("Hook not writable: $user_gitolite_bare_repo/hooks/$hookfile");
	  while(<H>) { s|\@\@BACKEND\@\@|$user_backend_repo|g; s|\@\@MIRROR\@\@||g; print H1 $_; }
	  close(H); close(H1);
	  chmod 0755, "$user_gitolite_bare_repo/hooks/$hookfile";
      }

      # tell gitweb about the new repo
      my $user_gitweb_bare_repo = $GITWEB_REPOS . "$username.git";
      my $ln_exit_code = system('ln', '-s', $user_gitolite_bare_repo, $user_gitweb_bare_repo);
      if ($ln_exit_code != 0) {
	my $ln_error_message = $ln_exit_code >> 8;
        pr_die_unlock ("Un oh: something went wrong linking '$user_gitolite_bare_repo' to '$user_gitweb_bare_repo':<blockquote>" . escapeHTML ($!) . "</blockquote><p>Please complain loudly to the administrators.");
      }

      # install hooks in the backend

      foreach my $hookfile ("pre-commit", "post-commit")
      {
	  copy("$MWADMIN_DIR/$hookfile", "$user_backend_repo/.git/hooks")
	      or pr_die_unlock ("Cannot copy $hookfile to $user_backend_repo/.git/hooks");
	  chmod 0755, "$user_backend_repo/.git/hooks/$hookfile";
      }

      # add the username to the list of all users (this introduces
      # some redundancy in our data, but for the sake of convenience,
      # it's easier to manage a flat list of usernames)
      open (USERS, '>>', $gitolite_user_list_file)
	or pr_die_unlock ("Uh oh: something went wrong opening the user list file at '$gitolite_user_list_file':</p><blockquote>" . escapeHTML ($!) . "</blockquote><p>Please complain loudly to the administrators.</p>");
      print USERS ("$username\n")
	or pr_die_unlock ("Uh oh: something went wrong printing '$username' to the user list file:</p><blockquote>" . escapeHTML ($!) . "</blockquote><p>Please complain loudly to the administrators.</p>");
      close USERS
	or pr_die_unlock ("Uh oh: something went wrong closing the user list file at '$gitolite_user_list_file':</p><blockquote>" . escapeHTML ($!) . "</blockquote><p>Please complain loudly to the administrators.</p>");


      print_successful_registration_message ($username);
      unlockwiki ();
      
    } else {
      pr_die_unlock ($bad_username);
    }
  } else {
    print $registration_form;
  }
}

### TODO: This should be a session file

if ($action eq 'users') {
  my @users = ();
  lockwiki ();
  open (USERS, '<', $gitolite_user_list_file)
    or pr_die_unlock ("Uh oh: cannot open the user list at '$gitolite_user_list_file:</p><blockquote" . escapeHTML ($!) . "</blockquote><p>Please complain loudly to the administators.</p>");
  while (defined (my $user = <USERS>)) {
    chomp $user;
    push (@users, $user);
  }
  close USERS
    or pr_die_unlock ("Uh oh: cannot close the user list at '$gitolite_user_list_file':</p><blockquote" . escapeHTML ($!) . "</blockquote><p>Please complain loudly to the administrators.</p>");
  print "<p>Below is a list of all users that have registered with us.  Follow the
link associated with a user to see that user's repository.</p>\n";
  if (scalar @users == 0) {
    print "<p><em>(No users have registered yet.)</em></p>"
  } else {
    print "<ul>";
    foreach my $user (@users) {
      print "<a href=\"$lgitwebcgi?p=$git_project;r=$user.git\">$user</a>";
    }
  }
  unlockwiki ();
}

  print $query->end_html;
