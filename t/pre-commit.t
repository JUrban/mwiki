use Test::More no_plan => 1;

BEGIN { use_ok ('mizar'); }
BEGIN { use_ok ('File::Temp', 'tempdir'); }
BEGIN { use_ok ('File::Copy'); }

my $num_mml_articles = 25;

# Testing out git hooks.  Simulate a variety of edits that could be
# done to an MML that is known to be correct.

# First, make sure that we have a working MIZFILES available.

my $mizfiles = $ENV{"MIZFILES"};

sub pad_real_mizfiles {
  my $pad = shift;
  return ($mizfiles . "/" . $pad);
}

ok (defined ($mizfiles), "MIZFILES is set in your environment");
ok (-d $mizfiles, "MIZFILES is a directory");
my $mml_lar = pad_real_mizfiles ("mml.lar");
ok (-e $mml_lar, "mml.lar exists under MIZFILES");

# Set up a cute little MML containing the articles that make up the
# top $num_mml_articles elements of mml.lar.

my @top_N = `head -n $num_mml_articles $mml_lar`;
is (scalar (@top_N), $num_mml_articles, 
    "get the top $num_mml_articles articles from mml.lar");
my $mml_dir = pad_real_mizfiles ("mml");
ok (-e $mml_dir, "mml subdirectory of MIZFILES exists");
ok (-d $mml_dir, "mml subdirectory of MIZFILES is a directory");

sub pad_real_mml {
  my $pad = shift;
  return ($mml_dir . "/" . $pad);
}

sub miz {
  my $aid = shift;
  return ($aid . ".miz");
}

ok (-e pad_real_mml (miz ("tarski")), "tarski.miz exists");

for my $article (@top_N) {
  chomp ($article);
  my $article_path = pad_real_mml (miz ($article));
  ok (-e $article_path, "ensuring that $article.miz exists under MML");
}

my $little_mizfiles = tempdir (CLEANUP => 0); # so we can look at the mess

sub pad_little_mizfiles {
  my $pad = shift;
  return ($little_mizfiles . "/" . $pad);
}

ok (-d $little_mizfiles, "able to create a new MIZFILES");
my $little_mizfiles_mml = pad_little_mizfiles ("mml");

sub pad_little_mml {
  my $pad = shift;
  return ($little_mizfiles_mml . "/" . $pad);
}

ok (mkdir ($little_mizfiles_mml), "create an mml subdirectory of new little MIZFILES");

sub pad_littlel_prel {
  my $pad = shift;
  return (pad_little_mizfiles ("prel" . "/" . $pad));
}

ok (copy (pad_real_mml (miz ("tarski")), pad_little_mml (miz ("tarski"))),
    "copy tarski.miz from the real MML to the little MML");
foreach my $article (@top_N) {
  my $real_article_path = pad_real_mml (miz ($article));
  my $new_article_path = pad_little_mml (miz ($article));
  ok (copy ($real_article_path, $new_article_path),
      "copy $article.miz from the real MML to the little MML");
}

# make a new prel directory
my $real_prel = pad_real_mizfiles ("prel");

sub pad_real_prel {
  my $pad = shift;
  return ($real_prel . "/" . $pad);
}

my $little_prel = pad_little_mizfiles ("prel");

sub pad_little_prel {
  my $pad = shift;
  return ($little_prel . "/" . $pad);
}

ok (-e $real_prel, "prel directory exists in the real MIZFILES");
ok (-d $real_prel, "prel directory is actually a directory under MIZFILES");
ok (mkdir ($little_prel), "making a prel directory");

# copy hidden's files from the real prel
my @hidden_extensions = qw/dco dno dre/;
for my $extension (@hidden_extensions) {
  my $real_hidden_file = pad_real_prel ("h" . "/" . "hidden." . $extension);
  my $new_hidden_file = pad_little_prel ("hidden." . $extension);
  ok (-e $real_hidden_file,
      "hidden.$extension exists under the real MIZFILES prel/h subdirectory");
  ok (copy ($real_hidden_file, $new_hidden_file),
      "copy $real_hidden_file to $new_hidden_file");
}

# set up a phony mml.lar in the new mizfiles
my $little_mml_lar = pad_little_mizfiles ("mml.lar");
`head -n $num_mml_articles $mml_lar > $little_mml_lar`;
ok (-e $little_mml_lar, 
    "wrote the top $num_mml_articles articles to a new fake mml.lar");
my @new_mml_lar_lines = `cat $little_mml_lar`;
is (scalar (@new_mml_lar_lines), $num_mml_articles, 
    "the new mml.lar has $num_mml_articles lines, too");

my @extra_miz_data = qw/miz.xml mizar.dct mizar.msg mml.ini mml.vct/;
foreach my $miz_data (@extra_miz_data) {
  my $real_miz_data = pad_real_mizfiles ($miz_data);
  my $new_miz_data = pad_little_mizfiles ($miz_data);
  ok (-e $real_miz_data, "data file $miz_data exists");
  ok (copy ($real_miz_data, $new_miz_data),
     "copy $miz_data from real MML to little MML");
}

# Requirements: arithm boole hidden numerals real subset
my $real_arithm_dre = pad_real_prel ("a" . "/" . "arithm.dre");
ok (-e $real_arithm_dre, "making sure arithm.dre exists");
my $new_arithm_dre = pad_little_prel ("arithm.dre");
ok (copy ($real_arithm_dre, $new_arithm_dre),
   "copying arithm requirements to little prel");

my $real_boole_dre = pad_real_prel ("b" . "/" . "boole.dre");
ok (-e $real_boole_dre, "making sure boole.dre exists");
my $new_boole_dre = pad_little_prel ("boole.dre");
ok (copy ($real_boole_dre, $new_boole_dre),
   "copying boole requirements to little prel");

my $real_hidden_dre = pad_real_prel ("h" . "/" . "hidden.dre");
ok (-e $real_hidden_dre, "making sure hidden.dre exists");
my $new_hidden_dre = pad_little_prel ("hidden.dre");
ok (copy ($real_hidden_dre, $new_hidden_dre),
   "copying hidden requirements to little prel");

my $real_numerals_dre = pad_real_prel ("n" . "/" . "numerals.dre");
ok (-e $real_numerals_dre, "making sure numerals.dre exists");
my $new_numerals_dre = pad_little_prel ("numerals.dre");
ok (copy ($real_numerals_dre, $new_numerals_dre),
   "copying numerals requirements to little prel");

my $real_real_dre = pad_real_prel ("r" . "/" . "real.dre");
ok (-e $real_real_dre, "making sure real.dre exists");
my $new_real_dre = pad_little_prel ("real.dre");
ok (copy ($real_real_dre, $new_real_dre),
   "copying real requirements to little prel");

my $real_subset_dre = pad_real_prel ("s" . "/" . "subset.dre");
ok (-e $real_subset_dre, "making sure subset.dre exists");
my $new_subset_dre = pad_little_prel ("subset.dre");
ok (copy ($real_subset_dre, $new_subset_dre),
   "copying subset requirements to little prel");

# XSL
my $real_addabsrefs = "/Users/alama/sources/mizar/xsl4mizar/addabsrefs.xsl";
ok (-e $real_addabsrefs, "addabsrefs.xsl exists");
my $real_mizxsl = "/Users/alama/sources/mizar/xsl4mizar/miz.xsl";
ok (-e $real_mizxsl, "miz.xsl exists");

my $little_xslhome = pad_little_mizfiles ("xsl");
ok (mkdir ($little_xslhome), "make xsl subdir in little MIZFILES");

sub pad_little_xsl {
  my $pad = shift ();
  return ($little_mizfiles . "/" . "xsl" . "/" . $pad);
}

my $little_addabsrefs = pad_little_xsl ("addabsrefs.xsl");
ok (copy ($real_addabsrefs, $little_addabsrefs),
    "copy addabsrefs.xsl to little MIZFILES");
my $little_mizxsl = pad_little_xsl ("miz.xsl");
ok (copy ($real_mizxsl, $little_mizxsl),
    "copy miz.xsl to little MIZFILES");


diag ("We've now set up a little MIZFILES under $little_mizfiles.",
      "Further work will now be carried out there");

chdir ($little_mizfiles);

ok (mizar::set_MIZFILES ($little_mizfiles),
    "setting the mizar package's MIZFILES");

diag ("Generating dependency makefile for the little MIZFILES");

my $dependency_makefile_str = mizar::mml_dependencies_as_makefile_str ();

ok (defined ($dependency_makefile_str), "the generated makefile is, at least, defined");
ok (length ($dependency_makefile_str) > 500, "the generated makefile isn't too short");
diag ("Generated makefile:\n$dependency_makefile_str");
my $dep_makefile_fh;
my $dep_makefile_path = pad_little_mizfiles ("Makefile");
ok (open ($dep_makefile_fh, q{>}, $dep_makefile_path),
    "open an output filehandle for $dep_makefile_path");
print $dep_makefile_fh ($dependency_makefile_str);
ok (close ($dep_makefile_fh), "close the output filehandle for $dep_makefile_path");

diag ("Attempting to build the all target of the newly generated makefile");

my $make_xml_err_file = pad_little_mizfiles ("make-xml-err");
my $make_xml_out_file = pad_little_mizfiles ("make-xml-out");
my $make_xml_result = `MIZFILES=$little_mizfiles make --makefile $dep_makefile_path xml > $make_xml_out_file 2> $make_xml_err_file`;
ok (-z $make_xml_err_file, "testing verification/XML generation build");

my $make_html_err_file = pad_little_mizfiles ("make-html-err");
my $make_html_out_file = pad_little_mizfiles ("make-html-out");
my $make_html_result = `MIZFILES=$little_mizfiles make --makefile $dep_makefile_path html > $make_html_out_file 2> $make_html_err_file`;
# this is going to fail on my machine because I don't have the custom
# mizar verifier that inserts the proper data into the XML.
ok (-z $make_html_err_file, "testing HTML build");

