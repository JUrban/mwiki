#!//bin/sh

repos_base=/tmp/mwiki
mizfiles=/home/alama/share/mizar
mizbin=/home/alama/src/mizar/mizar-source-git

if [ "$1" -eq "clean" ]; then
    make -f Makefile.install clean \
	REPOS_BASE=$repos_base \
	MIZFILES=$mizfiles \
	MIZBIN=$mizbin;
else
    make -f Makefile.install html repo-export \
	REPOS_BASE=$repos_base \
	MIZFILES=$mizfiles \
	MIZBIN=$mizbin;
fi
