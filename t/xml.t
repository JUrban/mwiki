use Test::More tests => 13;

# Test various XML operations on mizar articles (and possibly abstracts, too)

BEGIN { use_ok ('File::Temp', 'tempdir'); }
BEGIN { use_ok ('File::Copy'); }
BEGIN { use_ok ('Carp'); }
BEGIN { use_ok ('mizar'); }
BEGIN { use_ok ('Cwd'); }
BEGIN { use_ok ('XML::LibXML'); }

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
my $zfrefle1_initial_comment = ":: Wazzup, Grzegorczyk" . "\n" . "\n" . $original_zfrefle1;

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

  <xsl:template match="\@line" />

  <xsl:template match="\@col" />

  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
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
	    $xsl_filename, $original_zfrefle1_xml_filename),
    0,
    "strip line and column infor from original article");
my $zfrefle1_initial_comment_xml_filename =
  $tempdir2_mml . "/" . "zfrefle1.xml";
my $zfrefle1_initial_comment_stripped_filename = "$tempdir2_mml" . "/" . "zfrefle1.stripped";
is (system ("xsltproc",
	    "--output", $zfrefle1_initial_comment_stripped_filename,
	   $xsl_filename, $zfrefle1_initial_comment_xml_filename),
    0,
    "strip line and column info from padded article");

# I don't know how to test identity of XML documents, so for now I'll
# just use diff on the newly-created .stripped files.

is (system ("diff",
	    "--brief",
	    $original_zfrefle1_stripped_filename,
	    $zfrefle1_initial_comment_stripped_filename),
    0,
    "testing character identity of stripped abstracts");


# Change the author -- this keeps the line and column counts the same
my $zfrefle1_new_author = $original_zfrefle1;
$zfrefle1_new_author =~ s/Grzegorz Bancerek/Barack Obama/;

# Insert some whitespace at the beginning of every line, thereby screwing with column counts
my $zfrefle1_padded_with_spaces = $original_zfrefle1;
$zfrefle1_padded_with_spaces =~ s/^/     /;

# Send every proof to @proof.
#
# The full article XML should be different, but the abstract XML
# should be identical to the initial XML.
