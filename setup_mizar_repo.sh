#!/bin/bash
# usage $1 = repo-directory; $2=full path xsl4mizar directory ; $3 full path mwiki directory
REPO=$1
XSL4MIZ=$2
MWIKI=$3

if [ -e $REPO ]; then
    echo "Target repository $REPO already exists; overwriting anyway...";
fi
mkdir -p $REPO

cp -a $MIZFILES/mml $REPO/mml
mkdir -p $REPO/prel
cp -p $MIZFILES/prel/h/hidden.* $REPO/prel
cp -p $MIZFILES/prel/*/*.dre $REPO/prel
cp  $MIZFILES/mml.* $REPO
cp  $MIZFILES/mizar.* $REPO
cp -a $MIZFILES/bin $REPO/bin
mkdir $REPO/xsl
cp $XSL4MIZ/addabsrefs.xsl $REPO/xsl
cp $XSL4MIZ/miz.xsl $REPO/xsl

mkdir $REPO/.perl
cp $XSL4MIZ/mkxmlhead.pl $REPO/.perl
cp $MWIKI/mizar.pm $REPO/.perl
cp $MWIKI/Makefile-mmlrepo $REPO/Makefile

cd $REPO
git init
cp $MWIKI/mml-gitignore .gitignore
mkdir -p .git/hooks
cp $MWIKI/pre-commit .git/hooks
cp $MWIKI/post-commit .git/hooks
git add .

echo "Making xml...here we go...";
MMLLAR=`cat mml.lar`;
make xml;
