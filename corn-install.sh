#!/bin/bash
# Coq and Corn installer/compiler
#
# usage:
#
# ./corn-install.sh /home/urban/ctest1

if [ -z "$1" ]
then 
    echo "> `basename $0` error : Missing parameter" 
    echo "Usage: `basename $0` absolute_directory_to_which_install" 
    exit 1
fi

mkdir $1
cd $1
wget http://coq.inria.fr/distrib/V8.2pl2/files/coq-8.2pl2.tar.gz
tar xzf coq-8.2pl2.tar.gz
cd coq-8.2pl2
./configure -local
time make -j12 world  # quite fast
export PATH=$1/coq-8.2pl2/bin:$PATH
cd $1
git clone http://www.fnds.cs.ru.nl/git/CoRN.git
cd CoRN
export COQTOP=$1/coq-8.2pl2
time make -j12   # will take 37 min - low parallelization
