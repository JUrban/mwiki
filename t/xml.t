use Test::More tests => 13;

# Test various XML operations on mizar articles (and possibly abstracts, too)

BEGIN { use_ok ('File::Temp', 'tempdir'); }
BEGIN { use_ok ('File::Copy'); }
BEGIN { use_ok ('Carp'); }
BEGIN { use_ok ('mizar'); }
BEGIN { use_ok ('Cwd'); }
BEGIN { use_ok ('XML::LibXML'); }
BEGIN { use_ok ('XML::SemanticDiff'); }
BEGIN { use_ok ('Test::XML'); }
BEGIN { use_ok ('XML::LibXSLT'); }

my $real_mizfiles = $ENV{"MIZFILES"};

my $exporter_path = `which exporter`;
chomp ($exporter_path);
isnt ($exporter_path, "", "ensure that exporter is for real");
is (mizar::set_exporter_path ($exporter_path), 0, "setting exporter path");

my $makeenv_path = `which makeenv`;
chomp ($makeenv_path);
isnt ($makeenv_path, "", "ensure that makeenv is for real");
is (mizar::set_makeenv_path ($makeenv_path), 0, "setting makeenv path");

# I've arbitrarily chosen zfrefle1
my $original_zfrefle1 = "";
my $zfrefle1_fh;
my $zfrefle1_line;
my $original_zfrefle1_path = $real_mizfiles . "/" . "mml" . "/" . "zfrefle1.miz";
open ($zfrefle1_fh, q{<}, $original_zfrefle1_path)
  or croak ("Can't open zfrefle1.miz!");
while (defined ($zfrefle1_line = <$zfrefle1_fh>)) {
  $original_zfrefle1 .= $zfrefle1_line;
}
close ($zfrefle1_fh);

my $cwd = getcwd ();

# Put zfrefle1 into a tempdir
my $tempdir1 = mizar::sparse_MIZFILES_in_tempdir ();
my $tempdir1_mml = $tempdir1 . "/" . "mml";
my $original_zfrefle1_filename = $real_mizfiles . "/" . "mml" . "/" . "zfrefle1.miz";
my $original_zfrefle1_tempdir1_filename = $tempdir1_mml . "/" . "zfrefle1.miz";
copy ($original_zfrefle1_filename, $original_zfrefle1_tempdir1_filename);

# Set up phony MIZFILES, makeenv and compute abstract
mizar::set_MIZFILES ($tempdir1);
mizar::run_makeenv_in_dir ("zfrefle1", $tempdir1_mml);
mizar::run_exporter_in_dir ("zfrefle1", $tempdir1_mml);

# Insert some junk at the beginning -- this increases the line numbers for all propositions
my $zfrefle1_initial_comment 
  = ":: Wazzup, Grzegorczyk" . "\n" 
  . "\n" 
  . $original_zfrefle1;

# Copy this to another temp directory, etc.
my $tempdir2 = mizar::sparse_MIZFILES_in_tempdir ();
my $tempdir2_mml = $tempdir2 . "/" . "mml";
my $zfrefle1_initial_comment_filename = $tempdir2_mml . "/" . "zfrefle1.miz";
my $fh2;
open ($fh2, q{>}, $zfrefle1_initial_comment_filename)
  or croak ("Unable to open an output filehandle in $tempdir2");
print $fh2 ($zfrefle1_initial_comment);
close ($fh2)
  or croak ("Something went wrong when closing the output filehandle associated with $tempdir2");

# Set up phony MIZFILES, makeenv and compute abstract
mizar::set_MIZFILES ($tempdir2);
mizar::run_makeenv_in_dir ("zfrefle1", $tempdir2_mml);
mizar::run_exporter_in_dir ("zfrefle1", $tempdir2_mml);

# Apply an XSLT stylesheet to this
my $strip_lines_and_comments_xslt = <<END_XSL;
<?xml version='1.0' encoding='UTF-8'?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml"/>

  <xsl:template match="processing-instruction(&apos;xml-stylesheet&apos;)"/>

  <xsl:template match="\@line"/>

  <xsl:template match="\@col"/>

  <xsl:template match="\@href"/>

  <xsl:template match="\@mizfiles"/>

  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
END_XSL
my $xslhome_dir = tempdir ();
my $xsl_filename = $xslhome_dir . "/" . "strip.xsl";
my $xslhome_fh;
open ($xslhome_fh, q{>}, $xsl_filename)
  or croak ("Unable to open an output filehandle for our XSL under $xsl_filename");
print $xslhome_fh ($strip_lines_and_comments_xslt);
close ($xslhome_fh)
  or croak ("Unable to close the output filehandle (associated with $xsl_filename) for our XSL");

my $original_zfrefle1_xml_filename = 
  $tempdir1_mml . "/" . "zfrefle1.xml";
my $original_zfrefle1_stripped_filename = "$tempdir2_mml" . "/" . "zfrefle1.stripped";
is (system ("xsltproc", 
	    "--output", $original_zfrefle1_stripped_filename,
	    "--param", "href", "",
	    $xsl_filename, $original_zfrefle1_xml_filename),
    0,
    "strip line and column infor from original article");
my $zfrefle1_initial_comment_xml_filename =
  $tempdir2_mml . "/" . "zfrefle1.xml";
my $zfrefle1_initial_comment_stripped_filename = "$tempdir2_mml" . "/" . "zfrefle1.stripped";
is (system ("xsltproc",
	    "--output", $zfrefle1_initial_comment_stripped_filename,
	    "--param", "href", "",
	   $xsl_filename, $zfrefle1_initial_comment_xml_filename),
    0,
    "strip line and column info from padded article");

# I don't know how to test identity of XML documents using the XML
# tools, so for now I'll just use diff on the newly-created .stripped
# files.  This seems fragile to me, but I guess it works.

is (system ("diff",
	    "--brief",
	    $original_zfrefle1_stripped_filename,
	    $zfrefle1_initial_comment_stripped_filename),
    0,
    "testing character identity of stripped abstracts");

# my $original_zfrefle1_stripped_str = "";
# my $fh3;
# my $fh3_line;
# open ($fh3, q{<}, $original_zfrefle1_stripped_filename)
#   or croak ("Couldn't open the stripped abstract XML!");
# while (defined ($fh3_line = <$fh3>)) {
#   $original_zfrefle1_stripped_str .= $fh3_line;
# }
# close ($fh3);

my $original_zfrefle1_xml_as_str = "";
my $fh3;
my $fh3_line;
open ($fh3, q{<}, $original_zfrefle1_xml_filename)
  or croak ("Couldn't open the original abstract XML!");
while (defined ($fh3_line = <$fh3>)) {
  $original_zfrefle1_xml_as_str .= $fh3_line;
}
close ($fh3);

my $xslt = XML::XSLT->new ($strip_lines_and_comments_xslt, warnings => 1);
my $original_stripped_xml = $xslt->transform ($original_zfrefle1_xml_as_str);
my $original_zfrefle1_stripped_str = $original_stripped_xml->toString ();

my $zfrefle1_initial_comment_xml_as_str = "";
my $fh4;
my $fh4_line;
open ($fh4, q{<}, $zfrefle1_initial_comment_stripped_filename)
  or croak ("Couldn't open the stripped abstract XML!");
while (defined ($fh4_line = <$fh4>)) {
  $zfrefle1_initial_comment_stripped_str .= $fh4_line;
}
close ($fh4);

my $zfreflre1_initial_comment_stripped_xml 
  = $xslt->transform ($zfrefle1_initial_comment_xml_as_str);
my $zfrefle1_initial_comment_stripped_str 
  = $zfrefle1_initial_comment_stripped_xml->toString ();

isnt ($original_zfrefle1_stripped_str, "", "we got the original stripped XML as a string");
isnt ($zfrefle1_initial_comment_stripped_str, "", "we got the modified abstract XML as a string");

is_xml ($original_zfrefle1_stripped_str, $zfrefle1_initial_comment_stripped_str,
	"xml comparison");

is_xml ($original_zfrefle1_stripped_str, $zfrefle1_initial_comment_stripped_str,
	"xml comparison");

# Change the author -- this keeps the line and column counts the same
my $zfrefle1_new_author = $original_zfrefle1;
$zfrefle1_new_author =~ s/Grzegorz Bancerek/Barack Obama/;

my $tempdir3 = mizar::sparse_MIZFILES_in_tempdir ();
my $tempdir3_mml = $tempdir3 . "/" . "mml";
my $zfrefle1_new_author_filename = $tempdir3_mml . "/" . "zfrefle1.miz";
my $fh3;
open ($fh3, q{>}, $zfrefle1_new_author_filename)
  or croak ("Unable to open an output filehandle in $tempdir3");
print $fh3 ($zfrefle1_new_author);
close ($fh3)
  or croak ("Something went wrong when closing the output filehandle associated with $tempdir3");

# Set up phony MIZFILES, makeenv and compute abstract
mizar::set_MIZFILES ($tempdir3);
mizar::run_makeenv_in_dir ("zfrefle1", $tempdir3_mml);
mizar::run_exporter_in_dir ("zfrefle1", $tempdir3_mml);

my $zfrefle1_new_author_xml_filename =
  $tempdir3_mml . "/" . "zfrefle1.xml";
my $zfrefle1_new_author_stripped_filename = "$tempdir3_mml" . "/" . "zfrefle1.stripped";
is (system ("xsltproc",
	    "--output", $zfrefle1_new_author_stripped_filename,
	    "--param", "href", "",
	   $xsl_filename, $zfrefle1_new_author_xml_filename),
    0,
    "strip line and column info from padded article");

# is (system ("diff",
# 	    "--brief",
# 	    $original_zfrefle1_stripped_filename,
# 	    $zfrefle1_new_author_stripped_filename),
#     0,
#     "testing character identity of stripped abstracts");

my $zfrefle1_new_author_stripped_str = "";
my $fh5;
my $fh5_line;
open ($fh5, q{<}, $zfrefle1_new_author_stripped_filename)
  or croak ("Couldn't open the stripped abstract XML!");
while (defined ($fh5_line = <$fh5>)) {
  $zfrefle1_new_author_stripped_str .= $fh5_line;
}
close ($fh5);

is_xml ($zfrefle1_new_author_stripped_str, $original_zfrefle1_stripped_str,
       "comparing new author xml");

# Insert some whitespace at the beginning of every line, thereby screwing with column counts
my $zfrefle1_padded_with_spaces = $original_zfrefle1;
$zfrefle1_padded_with_spaces =~ s/^/     /;

# Send every proof to @proof.
#
# The full article XML should be different, but the abstract XML
# should be identical to the initial XML.

# -*- mode: perl; -*-
