#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Pretty ":standard";
use IO::Socket;
use File::Temp qw/ :mktemp  /;
use HTTP::Request::Common;
use LWP::Simple;



my $frontend_dir  = "/var/cache/git/";

my $lgitwebcgi    = "http://mws.cs.ru.nl:1234/";
my $leditcgi    = "http://mws.cs.ru.nl/cgi-bin/mwiki/edit.cgi";

my $htmldir       = "http://mws.cs.ru.nl/~mizarw/mw";

my $query	  = new CGI;
my $ProblemSource = $query->param('ProblemSource');
my $input_article	  = $query->param('Formula');
my $git_project	  = $query->param('p');

# the file comes with relative path: mml/card_1.miz
my $input_file	  = $query->param('f');
my @miz_files = ($input_file);


my $frontend_repo = $frontend_dir . $git_project;

my $backend_repo_path = "";

my $article_filename = "";
my $aname = "";

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



print $query->header();

print $query->start_html(-title=>"Submitting $input_file",
			-head  => style(
{-type => 'text/css'},
'body {font-family: monospace; margin: 0px;}
.wikiactions ul { background-color: DarkSeaGreen ; color:blue; margin: 0; padding: 6px; list-style-type: none; border-bottom: 1px solid #000; }
.wikiactions li { display: inline; padding: .2em .4em; }'
                         )
);



if($input_file =~ /^mml\/((.*)\.miz)$/) { ($article_filename, $aname) = ($1, $2); }

my $viewlinks = "";

## only print the file links if the file is ok
sub printheader
{
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

if (defined($git_project) && defined($input_file) && (-d $frontend_repo))
{
    chdir $frontend_repo;
    $backend_repo_path = `git config mwiki.backend`;
    chomp($backend_repo_path);
}
else
{
    pr_print "The repository $git_project does not exist or input file not specified";
    print "</pre>";
    print $query->end_html;
    exit;
}

if(!(defined $backend_repo_path) || (length($backend_repo_path) == 0))
{
    pr_print "No backend repository for the project $git_project";
    print "</pre>";
    print $query->end_html;
    exit;
}

## TODO: stolen from pre-receive.in, this should be re-factored

# Ensure that all .miz files satisfy these conditions:
#
# 1 they are under the mml subdirectory
# 2 they are actually files, i.e., blobs in git terminology
# 3 their size is less than, say, one megabyte;
# 4 they have mode 644 ("should never happen", given condition #2)
my $miz_file = $input_file;
unless ($miz_file =~ /^mml\/(.*\.miz)$/) { # strip the "mml/" prefix
    pr_print ("Suspicious: .miz file is not under the mml subdirectory");
    pr_print ("The path is $miz_file");
    print "</pre>";
    print $query->end_html;
    exit;
}

my $miz_file_size = length($input_article);
unless ($miz_file_size < 1000000) {
    pr_print ("Suspicious: the .miz file $miz_file is bigger than one megabyte");
    print "</pre>";
    print $query->end_html;
    exit;
}




# Now let's try to commit these files to the backend repo.  First, we
# need to store them somewhere.  They are already on the server as
# objects.  I suppose we could just directly copy the files, using the
# SHA1 object names.  But just for the sake of simplicity, let's first
# use git show to do the job for us.
#
# How will we deal with the problem of possibly bad files?  We shall
# first copy the files in the backend repo that are supposed to be
# updated; these are known to be safe.  Then, we'll add the new .miz
# files to the backend repo, and call git add there on them.  Then
# we'll call git commit in the backend repo.  If this works, then we
# don't have anything else to do; we can delete the copies of the
# known safe .miz files that we made earlier.  IF something goes wrong
# with the pre-commit hook, then we move the known safe mizar files
# back into their original place.

my $backend_repo_mml = $backend_repo_path . "/" . "mml";

# Separate the old miz files -- the ones that already exist in the
# backend repo -- from the new miz files -- the genuinely new
# contributions.  To determine whether something is old/already
# exists, we'll use the old SHA1 that was given to this script as
# input.  It should point to a commit object (and hence, indirectly,
# to a tree object) that already exists on in the frontend repo.

sub strip_initial_mml {
  my $path = shift;
  $path =~ /^mml\/(.+\.miz$)/;
  my $stripped = $1;
  unless (defined $stripped) {
    die "Something went wrong when trying to strip the \"mml/\" from \"$path\"";
  }
  return $stripped;
}

# Copy the contents of the new
# new files to the backend repo.
foreach my $received_mml_miz_file (@miz_files) {
  chomp $received_mml_miz_file;
  my $article_filename = strip_initial_mml ($received_mml_miz_file);
  my $received_path = $backend_repo_mml . "/" . $article_filename;
  open(PFH, ">$received_path") or die "$received_path not writable";
  printf(PFH "%s",$input_article);
  close(PFH);
  unless (-e $received_path) {
    die "We didn't output anything to $received_path";
  }
}

sub ensure_directory {
  my $maybe_dir = shift;
  if (-d $maybe_dir) {
    return $maybe_dir;
  } else {
    croak ("The given directory, $maybe_dir, is not actually a directory");
  }
}

sub move_all_files_from_to {
  my $source_dir = ensure_directory (shift);
  my $target_dir = ensure_directory (shift);
  `find $source_dir -type f -depth 0 -exec mv {} $target_dir ";"`;
  my $find_exit_status = ($? >> 8);
  if ($find_exit_status == 0) {
    return;
  } else {
    croak ("Error copying the files from $source_dir to $target_dir!");
  }
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
system ("git add @miz_files 2>&1");
my $git_add_exit_code = ($? >> 8);
unless ($git_add_exit_code == 0) {
  pr_print ("Error adding the new mizar files to the backend repository:");
  pr_print ("The exit code was $git_add_exit_code");

  system ("git reset HEAD 2>&1");
  system ("git checkout -- 2>&1");
#  move_all_files_from_to ($purgatory_mml, $backend_repo_mml);
  print "</pre>";
  print $query->end_html;
  exit;
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

  # The commit failed, so we need to resurrect the files in purgatory
#  move_all_files_from_to ($purgatory_mml, $backend_repo_mml);
    print "</pre>";
  print $query->end_html;
  exit;
}

# If we made it this far, then we deserve a break.
exit 0;
