#!/bin/bash

# usage: 
#
# $1 = repo-directory
# $2=full path xsl4mizar directory
# $3 full path mwiki directory
# $4 = number of articles from MML.LAR to work with

REPO=$1
XSL4MIZ=$2
MWIKI=$3
NUM_ARTICLES=$4

MIZBINARIES="absedt accom addfmsg \
             checkvoc chklab clearenv.pl constr \
             edtfile envget errflag exporter \
             findvoc \
             inacc irrths irrvoc \
             lisppars listvoc \
             makeenv mglue miz2abs miz2prel mizf msplit \
             prune \
             ratproof relinfer reliters relprem remflags renthlab revedt revf \
             transfer trivdemo \
             verifier";

if [ -z $MIZBIN ]; then
    MIZBIN=$MIZFILES/bin;
else
    MIZBIN=$MIZBIN;
fi

if [ -z $MAKEJOBS ]; then
    MAKEJOBS=1;
else
    MAKEJOBS=$MAKEJOBS;
fi

if [ -e $REPO ]; then
    echo "Target repository $REPO already exists; overwriting...";
fi

mkdir -p $REPO/mml

INITIAL_SEGMENT=`head -n $NUM_ARTICLES $MIZFILES/mml.lar`
for article in $INITIAL_SEGMENT; do
    install --preserve-timestamps --verbose $MIZFILES/mml/$article.miz $REPO/mml;
done
# ensure tarski and hidden are present, too
cp -p $MIZFILES/mml/hidden.miz $REPO/mml
cp -p $MIZFILES/mml/tarski.miz $REPO/mml

# Special prel files
mkdir -p $REPO/prel
cp -p $MIZFILES/prel/h/hidden.* $REPO/prel
cp -p $MIZFILES/prel/*/*.dre $REPO/prel

# Other mizar data
cp  $MIZFILES/mml.ini $REPO
cp  $MIZFILES/mml.vct $REPO
echo $INITIAL_SEGMENT > $REPO/mml.lar
cp -p $MIZFILES/mizar.* $REPO

# Set up binaries
REPOBIN=$REPO/bin
mkdir -p $REPOBIN
for binary in $MIZBINARIES; do
    install --preserve-timestamps --mode 755 $MIZBIN/$binary $REPOBIN/$binary;
done

# XSL
mkdir $REPO/xsl
SHEETS="addabsrefs miz evl2dep"
for sheet in $SHEETS; do
    install --mode 644 --preserve-timestamps $XSL4MIZ/$sheet.xsl $REPO/xsl;
done

# Perl
mkdir $REPO/.perl
PERLSCRIPTS="mkxmlhead.pl mkmmlindex.pl"
PERLMODULES="mizar.pm"
for perlfile in $PERLMODULES; do
    install --preserve-timestamps --mode 644 $XSL4MIZ/$perlfile $REPO/.perl;
done
for perlfile in $PERLSCRIPTS; do
    install --preserve-timestamps --mode 755 $XSL4MIZ/$perlfile $REPO/.perl;
done

# Our central makefile and helper scripts
install --mode 644 $MWIKI/Makefile.repo $REPO/Makefile
install --mode 755 $MWIKI/duplicates.pl $REPO


# Construct the initial master git repo
cd $REPO
git init

git config --add description "The mizar wiki"

# instaweb/gitweb configuration

# I'm not happy with using instaweb; it is designed for one-off
# browsing of the repo.  We should have a more robust server-based
# solution, like a bona fide gitweb installation.
git config --add instaweb.httpd apache2 
git config --add instaweb.port 1234
git config --add instaweb.modulepath /usr/lib/apache2/modules

install -m 644 $MWIKI/mml-gitignore .gitignore

git add .
git commit -m 'Initial commit.'

# Start gitweb
# git instaweb --restart 

# We put these in the git repo after the initial commit because
# calling the hook on the initial commit doesn't make sense (there's
# no index, and HEAD points to nothing).
install -m 755 -D $MWIKI/pre-commit .git/hooks
install -m 755 -D $MWIKI/post-commit .git/hooks

echo "Making the deps...here we go...";
MMLLAR=`cat mml.lar`; # mml.lar in the repo, not $MIZFILES
cd mml
touch hidden-prel # everything depends on hidden-prel, so by touching
		  # this target we ensure that absolutely everything
		  # gets rebuilt
install -m 644 $MWIKI/Makefile-depsrepo Makefile
export MIZFILES=$REPO
export PATH=$PATH:$MIZBIN
make -j $MAKEJOBS evls deps
echo "That was fun.  Let's make the xml!  Grab some tea or coffee.";
cd $REPO
make -j $MAKEJOBS xmlvrfs prels absrefs htmls
echo "Successfully (???) compiled everything."

# Make our clean sandbox.
echo "Copying $REPO to $REPO-sandbox; this will be our sandbox." 
rsync -a --del --exclude=".gitignore" --exclude=".git/" --progress $REPO/ $REPO-sandbox
# note the trailing slash -- see the rsync man page to learn why   ===> ^ <===

# Export our repo, thereby making it accessible to the git daemon
cd $REPO
cd ..
git clone --bare $REPO $REPO.git

# We need to install our pre-receive hook (or is it an update hook?)
# at this point in the newly created bare repo.
install --mode 755 $MWIKI/pre-receive $REPO.git/hooks

echo "If everything went according to plan, then we just created the following:"
echo "* $REPO: a `fully-compiled' git repository with pre-commit and post-commit hooks;"
echo "* $REPO-sandbox: $REPO minus its git metadata; it will be our clean sandbox;"
echo "* $REPO.git, a bare clone of $REPO with a pre-receive hook; this will be publicly accessible"

exit 0; # I guess...

# We should be smarter about errors and keeping track of output.
# Ideally, we should say, at the end of all this, where a log of all
# of this activity can be found.  This whole setup feels pretty
# fragile.
