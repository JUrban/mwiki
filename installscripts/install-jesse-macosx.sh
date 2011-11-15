#!/bin/sh

repos_base=/tmp/var/cache/mwiki
mizfiles=/sw/share/mizar
mizbin=/Users/alama/sources/mizar/mizar-source-git
xsl4miz=/Users/alama/sources/mizar/xsl4mizar
num_articles=5


if [ "$1" = "clean" ]; then
    targets='clean'
else
    targets='public-repos'
fi

make -f Makefile.install $targets \
    REPOS_BASE=$repos_base \
    MIZFILES=$mizfiles \
    MIZBIN=$mizbin \
    XSL4MIZ=$xsl4miz \
    NUM_ARTICLES=$num_articles \
    PUBLIC_MWIKI_USER=alama \
    DEVEL_MWIKI_USER=alama \
    INSTALL=ginstall \
    ECHO=gecho \
    MAKEJOBS=4
