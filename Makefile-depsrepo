# -*- mode: makefile; -*-
MMLMIZALL=$(shell ls *.miz)
MMLMIZSTD=$(filter-out hidden.miz, $(MMLMIZALL))
MMLLAR=$(patsubst %.miz, %, $(MMLMIZSTD))
DEP-MAKEFILES = $(patsubst %, %.dep, $(MMLLAR))
EVL-FILES = $(patsubst %, %.evl, $(MMLLAR))
MIZ = $(patsubst %, %.miz, $(MMLLAR))

# .PHONY is a bad bad thing, it remakes the target all over; don't use this
#.PHONY: deps
#.PHONY: $(patsubst %, %-dep, $(MMLLAR))

ECHO=/bin/echo

dep-tag = "    DEP "
evl-tag = "    EVL "

.SECONDARY: $(patsubst %, %.evl, $(MMLLAR)) # don't auto-delete intermediate .dep files

# the deps file is dynamically created mml.lar
# dependencies in all .dep are printed as pairs and tsort-ed
# the regexp assumes files like foo.bla or foo-bla only, stripping the extension
deps: $(DEP-MAKEFILES)
	@cat $(DEP-MAKEFILES)| perl -e \
	'while(<>) {@a=m/([^-. :]+)[.-][a-z]+/g; foreach $$k (@a[1..$$#a]) {print $$a[0], " ", $$k,"\n";}}' \
	 | tee deps0 | tsort | tac > deps  

evls: $(EVL-FILES)

%.evl: %.miz
	@$(ECHO) $(evl-tag) $*;
	@envget $*.miz > /dev/null 2> /dev/null;

%.dep: %.evl
	@$(ECHO) $(dep-tag) $*;
	@xsltproc ../xsl/evl2dep1.xsl $*.evl | ../.perl/duplicates1.pl > $*.dep;
#	@xsltproc ../xsl/evl2dep.xsl $*.evl | ../.perl/duplicates.pl > $*.dep;
