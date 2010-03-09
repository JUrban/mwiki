#!/bin/bash
# usage $1 = repo-directory; $2=full path xsl4mizar directory ; $3 full path mwiki directory
REPO=$1
XSL4MIZ=$2
MWIKI=$3
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

cd $REPO
git init
cp $MWIKI/mml-gitignore .gitignore
git add .


