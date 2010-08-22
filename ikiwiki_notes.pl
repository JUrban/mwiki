## random notes about ikiwiki code, useful for planetmath and borrowing code for mathwiki

## IkiWiki/Setup.pm - utils run when --setup

## grep evaluates block for all array elements - findall
my @plugins=grep { $_ ne $config{rcs} } sort(IkiWiki::listplugins());

## plugins get evaluated: eval protects against "die", etc. inside the block
eval { IkiWiki::loadplugin($plugin) };
if (exists $IkiWiki::hooks{checkconfig}{$plugin}{call}) {
  my @s=eval { $IkiWiki::hooks{checkconfig}{$plugin}{call}->() };
}

## Plugins/progress.pm - seems that s!!! can be used as s///; seems that the scrubber can kill the style attribute
## seems that sub format(@) can be used after the scrubber!
sub format(@) {
  my %params = @_;
  # If HTMLScrubber has removed the style attribute, then bring it back
  $params{content} =~ s!<div class="progress-done">($percentage_pattern)</div>!<div class="progress-done" style="width:
 $1">$1</div>!g;
  return $params{content};
}

## Render.pm
## every page keeps its backlinks

## pages can be internal?
if (isinternal($page)) {push @internal, $pagesources{$page};}
## each page keeps its links?
$links{$page}=[];
## calculating links:
calculate_links();
## internal pages are not renedered:
foreach my $file (@internal) {
                # internal pages are not rendered
                my $page=pagename($file);
                delete $depends{$page};
                delete $depends_simple{$page};
                foreach my $old (@{$renderedfiles{$page}}) {
                        delete $destsources{$old};
                }
                $renderedfiles{$page}=[];
        }
## backlinks, rendering:
my $p=pagename($f);
foreach my $page (keys %{$backlinks{$p}}) {
  my $file=$pagesources{$page};
  next if $rendered{$file};
  render($file);
  $rendered{$file}=1;
}

## dependent pages:
if (exists $depends_simple{$p}) { ... }

## what are bestlinks?
if (exists $links{$page}) {
  foreach my $link (map { bestlink($page, $_) } @{$links{$page}}) { ... }}

## commandline rendering: - pagemtime, pagectime created here using stat()
## the order is: filter, preprocess, linkify, htmlize
sub commandline_render () {
        lockwiki();
        loadindex();
        unlockwiki();

        my $srcfile=possibly_foolish_untaint($config{render});
        my $file=$srcfile;
        $file=~s/\Q$config{srcdir}\E\/?//;

        my $type=pagetype($file);
        die sprintf(gettext("ikiwiki: cannot build %s"), $srcfile)."\n" unless defined $type;
        my $content=readfile($srcfile);
        my $page=pagename($file);
        $pagesources{$page}=$file;
        $content=filter($page, $page, $content);
        $content=preprocess($page, $page, $content);
        $content=linkify($page, $page, $content);
        $content=htmlize($page, $page, $type, $content);
        $pagemtime{$page}=(stat($srcfile))[9];
        $pagectime{$page}=$pagemtime{$page} if ! exists $pagectime{$page};

        print genpage($page, $content);
        exit 0;
}

## Plugins/pagetemplate.pm: preprocess used to do template stuff?
sub preprocess (@) {
        my %params=@_;

        if (! exists $params{template} ||
            $params{template} !~ /^[-A-Za-z0-9._+]+$/ ||
            ! defined IkiWiki::template_file($params{template})) {
                 error gettext("bad or missing template")
        }
        if ($params{page} eq $params{destpage}) {
                $templates{$params{page}}=$params{template};
        }
        return "";
}

sub templatefile (@) {
        my %params=@_;

        if (exists $templates{$params{page}}) {
                return $templates{$params{page}};
        }
        return undef;
}

## templates
## page.tmpl titles, favicons, stylesheets, 
title><TMPL_VAR TITLE></title>
<TMPL_IF NAME="FAVICON">
<link rel="icon" href="<TMPL_VAR BASEURL><TMPL_VAR FAVICON>" type="image/x-icon" />
</TMPL_IF>

## wiki editing:
<TMPL_IF NAME="EDITURL">
<link rel="alternate" type="application/x-wiki" title="Edit this page" href="<TMPL_VAR EDITURL>" />
</TMPL_IF>

## parentlinks:
<span class="parentlinks">
<TMPL_LOOP NAME="PARENTLINKS">
<a href="<TMPL_VAR URL>"><TMPL_VAR PAGE></a>/
</TMPL_LOOP>
</span>

## recentchanges.tmpl - should be changed to xhtml (or the planetmath pages should - how?)

