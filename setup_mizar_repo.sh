#!/bin/bash
# usage $1 = repo-directory
REPO=$1
mkdir -p $REPO
cp -a $MIZFILES/mml $REPO/mml
mkdir -p $REPO/prel
cp -p $MIZFILES/prel/h/hidden.* $REPO/prel
cp -p $MIZFILES/prel/*/*.dre $REPO/prel
cp  $MIZFILES/mml.* $REPO
cp  $MIZFILES/mizar.* $REPO
cp $MIZFILES/bin $REPO

