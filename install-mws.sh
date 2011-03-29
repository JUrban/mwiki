#!/bin/sh

repos_base=/var/cache/mwiki
#mizfiles=/home/mptp/mizwrk/7.11.05_4.133.1080
mizfiles=/home/alama/mizinst/7.11.06_4.150.1103
xsl4miz=/home/alama/xsl4mizar
num_articles=5


if test -z "$1"; then
    targets='repos'
else
    targets=$1
fi

make -f Makefile.smallinstall $targets \
    REPOS_BASE=$repos_base \
    MIZFILES=$mizfiles \
    XSL4MIZ=$xsl4miz \
    NUM_ARTICLES=$num_articles \
    PUBLIC_MWIKI_USER=www-data \
    MAKEJOBS=8 \
    WIKIHOST=mizar.cs.ualberta.ca
