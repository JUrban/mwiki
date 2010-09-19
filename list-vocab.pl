#!/usr/bin/perl -w

# quickly extract the content of the vocabulary environment for an
# article.
#
# This kind of tool has probably been written a billion times.  Oh well.

sub usage {
  print ("Usage: list-vocab.pl ARTICLE\n");
}

if ($#ARGV == -1 || $#ARGV > 0) { # huh? why -1?
  usage ();
  exit (0);
}

# DEBUG
# warn ("number of arguments: $#ARGV\n");

my $article_base = $ARGV[0];
my $article_miz = $article_base . '.miz';
my $article_evl = $article_base . '.evl';

unless (-e $article_evl) {
  warn ("evl file for $article_base does not exist; creating it...");
  system ("makeenv $article_miz > /dev/null 2> /dev/null");
  unless ($? == 0) {
    die ("Something went wrong when calling makeenv on $article_base.\nThe error was:\n\n  $!");
  }
}

# cheap approach: take advantage of the fact the the Directives in the
# EVL file all begin at the beginning of the line
my $vocabulary_evl_directive = "sed -n -e '/^<Directive name=\"Vocabularies\"/,/^<\\/Directive/p' $article_evl";
# another cheap trick like the one above
my $select_identifiers = 'grep "^<Ident name="';

# now delete all the padding
my $name_equals_field = 'cut -f 2 -d \' \'';
my $name_right_hand_side = 'cut -f 2 -d \'=\'';
my $de_double_quote = 'sed -e \'s/"//g\'';

my $big_pipe = "$vocabulary_evl_directive | $select_identifiers | $name_equals_field | $name_right_hand_side | $de_double_quote";

# DEBUG
# warn ("about execute this big guy:\n\n  $big_pipe");

my @vocabs = `$big_pipe`;
if ($? == 0) {
  foreach my $vocab (@vocabs) {
    print ($vocab);
  }
} else {
  die ("Something went wrong executing the command\n\n$big_pipe\n\nThe error was: $!");
}
