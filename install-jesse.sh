#!/bin/sh

repos_base=/var/cache/mwiki
mizfiles=/home/alama/share/mizar
mizbin=/home/alama/src/mizar/mizar-source-git
xsl4miz=/home/alama/src/mizar/xsl4mizar
num_articles=2

if [ "$1" = "clean" ]; then
    targets='clean'
else
    targets='public-repos mwiki gitweb'
fi

make -f Makefile.install $targets \
	REPOS_BASE=$repos_base \
	MIZFILES=$mizfiles \
	MIZBIN=$mizbin \
	XSL4MIZ=$xsl4miz \
	NUM_ARTICLES=$num_articles;
