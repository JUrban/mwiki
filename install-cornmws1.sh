#!/bin/sh

repos_base=/var/cache/cwiki
libfiles=/home/urban/ec/CoRN
coqbin=/home/urban/ec/coq-8.2/bin
num_articles=10


if test -z "$1"; then
    targets='repos'
else
    targets=$1
fi

make -f Makefile.corninstall $targets \
    REPOS_BASE=$repos_base \
    COQBIN=$coqbin \
    LIBFILES=$libfiles \
    NUM_ARTICLES=$num_articles \
    PUBLIC_MWIKI_USER=www-data \
    MAKEJOBS=8 \
    WIKIHOST=mws.cs.ru.nl \
    REPO_NAME=cwiki

