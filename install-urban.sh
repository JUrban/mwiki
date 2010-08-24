#!/bin/sh

repos_base=/var/cache/mwiki
mizfiles=/home/urban/mizinst/7.11.06_4.145.1096
xsl4miz=/home/urban/gr/xsl4mizar
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
    MAKEJOBS=2 \
    WIKIHOST=localhost
