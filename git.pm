#!/usr/bin/perl -w
package git;

use warnings;
use strict;
# use IkiWiki;
use Encode;
use open qw{:utf8 :std};


# This is the useful git stuff borrowed and modified from ikwiki's git plugin.
# I am still not sure that we should be copy so much code instead of re-using ikiwiki,
# it feels like we are doing a lot of dumb code copying instead of smart re-use. Whatever.


my $sha1_pattern     = qr/[0-9a-fA-F]{40}/; # pattern to validate Git sha1sums
my $dummy_commit_msg = 'dummy commit';      # message to skip in recent changes
my $no_chdir=0;


sub parse_diff_tree ($@) {
	# Parse the raw diff tree chunk and return the info hash.
	# See git-diff-tree(1) for the syntax.

	my ($prefix, $dt_ref) = @_;

	# End of stream?
	return if !defined @{ $dt_ref } ||
		  !defined @{ $dt_ref }[0] || !length @{ $dt_ref }[0];

	my %ci;
	# Header line.
	while (my $line = shift @{ $dt_ref }) {
		return if $line !~ m/^(.+) ($sha1_pattern)/;

		my $sha1 = $2;
		$ci{'sha1'} = $sha1;
		last;
	}

	# Identification lines for the commit.
	while (my $line = shift @{ $dt_ref }) {
		# Regexps are semi-stolen from gitweb.cgi.
		if ($line =~ m/^tree ([0-9a-fA-F]{40})$/) {
			$ci{'tree'} = $1;
		}
		elsif ($line =~ m/^parent ([0-9a-fA-F]{40})$/) {
			# XXX: collecting in reverse order
			push @{ $ci{'parents'} }, $1;
		}
		elsif ($line =~ m/^(author|committer) (.*) ([0-9]+) (.*)$/) {
			my ($who, $name, $epoch, $tz) =
			   ($1,   $2,    $3,     $4 );

			$ci{  $who          } = $name;
			$ci{ "${who}_epoch" } = $epoch;
			$ci{ "${who}_tz"    } = $tz;

			if ($name =~ m/^[^<]+\s+<([^@>]+)/) {
				$ci{"${who}_username"} = $1;
			}
			elsif ($name =~ m/^([^<]+)\s+<>$/) {
				$ci{"${who}_username"} = $1;
			}
			else {
				$ci{"${who}_username"} = $name;
			}
		}
		elsif ($line =~ m/^$/) {
			# Trailing empty line signals next section.
			last;
		}
	}

	debug("No 'tree' seen in diff-tree output") if !defined $ci{'tree'};
	
	if (defined $ci{'parents'}) {
		$ci{'parent'} = @{ $ci{'parents'} }[0];
	}
	else {
		$ci{'parent'} = 0 x 40;
	}

	# Commit message (optional).
	while ($dt_ref->[0] =~ /^    /) {
		my $line = shift @{ $dt_ref };
		$line =~ s/^    //;
		push @{ $ci{'comment'} }, $line;
	}
	shift @{ $dt_ref } if $dt_ref->[0] =~ /^$/;

	# Modified files.
	while (my $line = shift @{ $dt_ref }) {
		if ($line =~ m{^
			(:+)       # number of parents
			([^\t]+)\t # modes, sha1, status
			(.*)       # file names
		$}xo) {
			my $num_parents = length $1;
			my @tmp = split(" ", $2);
			my ($file, $file_to) = split("\t", $3);
			my @mode_from = splice(@tmp, 0, $num_parents);
			my $mode_to = shift(@tmp);
			my @sha1_from = splice(@tmp, 0, $num_parents);
			my $sha1_to = shift(@tmp);
			my $status = shift(@tmp);

			# git does not output utf-8 filenames, but instead
			# double-quotes them with the utf-8 characters
			# escaped as \nnn\nnn.
			if ($file =~ m/^"(.*)"$/) {
				($file=$1) =~ s/\\([0-7]{1,3})/chr(oct($1))/eg;
			}
			$file =~ s/^\Q$prefix\E//;
			if (length $file) {
				push @{ $ci{'details'} }, {
					'file'      => decode("utf8", $file),
					'sha1_from' => $sha1_from[0],
					'sha1_to'   => $sha1_to,
					'mode_from' => $mode_from[0],
					'mode_to'   => $mode_to,
					'status'    => $status,
				};
			}
			next;
		};
		last;
	}

	return \%ci;
}


sub git_commit_info ($;$) {
	# Return an array of commit info hashes of num commits
	# starting from the given sha1sum.
	my ($sha1, $num) = @_;

	my @opts;
	push @opts, "--max-count=$num" if defined $num;

	my @raw_lines = run_or_die('git', 'log', @opts,
		'--pretty=raw', '--raw', '--abbrev=40', '--always', '-c',
		'-r', $sha1, '--', '.');
	my ($prefix) = run_or_die('git', 'rev-parse', '--show-prefix');

	my @ci;
	while (my $parsed = parse_diff_tree(($prefix or ""), \@raw_lines)) {
		push @ci, $parsed;
	}

	warn "Cannot parse commit info for '$sha1' commit" if !@ci;

	return wantarray ? @ci : $ci[0];
}


sub git_sha1 (;$) {
	# Return head sha1sum (of given file).
	my $file = shift || q{--};

	# Ignore error since a non-existing file might be given.
	my ($sha1) = run_or_non('git', 'rev-list', '--max-count=1', 'HEAD',
		'--', $file);
	if ($sha1) {
		($sha1) = $sha1 =~ m/($sha1_pattern)/; # sha1 is untainted now
	}
	else {
		debug("Empty sha1sum for '$file'.");
	}
	return defined $sha1 ? $sha1 : q{};
}


sub rcs_recentchanges ($) {
	# List of recent changes.

	my ($num) = @_;

	eval q{use Date::Parse};
	error($@) if $@;

	my @rets;
	foreach my $ci (git_commit_info('HEAD', $num || 1)) {
		# Skip redundant commits.
		next if ($ci->{'comment'} && @{$ci->{'comment'}}[0] eq $dummy_commit_msg);

		my ($sha1, $when) = (
			$ci->{'sha1'},
			$ci->{'author_epoch'}
		);

		my @pages;
		foreach my $detail (@{ $ci->{'details'} }) {
			my $file = $detail->{'file'};

			my $diffurl = defined $config{'diffurl'} ? $config{'diffurl'} : "";
			$diffurl =~ s/\[\[file\]\]/$file/go;
			$diffurl =~ s/\[\[sha1_parent\]\]/$ci->{'parent'}/go;
			$diffurl =~ s/\[\[sha1_from\]\]/$detail->{'sha1_from'}/go;
			$diffurl =~ s/\[\[sha1_to\]\]/$detail->{'sha1_to'}/go;
			$diffurl =~ s/\[\[sha1_commit\]\]/$sha1/go;

			push @pages, {
				page => pagename($file),
				diffurl => $diffurl,
			};
		}

		my @messages;
		my $pastblank=0;
		foreach my $line (@{$ci->{'comment'}}) {
			$pastblank=1 if $line eq '';
			next if $pastblank && $line=~m/^ *(signed[ \-]off[ \-]by[ :]|acked[ \-]by[ :]|cc[ :])/i;
			push @messages, { line => $line };
		}

		my $user=$ci->{'author_username'};
		my $web_commit = ($ci->{'author'} =~ /\@web>/);
		
		# compatability code for old web commit messages
		if (! $web_commit &&
		      defined $messages[0] &&
		      $messages[0]->{line} =~ m/$config{web_commit_regexp}/) {
			$user = defined $2 ? "$2" : "$3";
			$messages[0]->{line} = $4;
		 	$web_commit=1;
		}

		push @rets, {
			rev        => $sha1,
			user       => $user,
			committype => $web_commit ? "web" : "git",
			when       => $when,
			message    => [@messages],
			pages      => [@pages],
		} if @pages;

		last if @rets >= $num;
	}

	return @rets;
}


sub rcs_receive () {
	# The wiki may not be the only thing in the git repo.
	# Determine if it is in a subdirectory by examining the srcdir,
	# and its parents, looking for the .git directory.
	my $subdir="";
	my $dir=$config{srcdir};
	while (! -d "$dir/.git") {
		$subdir=IkiWiki::basename($dir)."/".$subdir;
		$dir=IkiWiki::dirname($dir);
		if (! length $dir) {
			error("cannot determine root of git repo");
		}
	}

	my @rets;
	while (<>) {
		chomp;
		my ($oldrev, $newrev, $refname) = split(' ', $_, 3);
		
		# only allow changes to gitmaster_branch
		if ($refname !~ /^refs\/heads\/\Q$config{gitmaster_branch}\E$/) {
			error sprintf(gettext("you are not allowed to change %s"), $refname);
		}
		
		# Avoid chdir when running git here, because the changes
		# are in the master git repo, not the srcdir repo.
		# The pre-recieve hook already puts us in the right place.
		$no_chdir=1;
		my @changes=git_commit_info($oldrev."..".$newrev);
		$no_chdir=0;

		foreach my $ci (@changes) {
			foreach my $detail (@{ $ci->{'details'} }) {
				my $file = $detail->{'file'};

				# check that all changed files are in the
				# subdir
				if (length $subdir &&
				    ! ($file =~ s/^\Q$subdir\E//)) {
					error sprintf(gettext("you are not allowed to change %s"), $file);
				}

				my ($action, $mode, $path);
				if ($detail->{'status'} =~ /^[M]+\d*$/) {
					$action="change";
					$mode=$detail->{'mode_to'};
				}
				elsif ($detail->{'status'} =~ /^[AM]+\d*$/) {
					$action="add";
					$mode=$detail->{'mode_to'};
				}
				elsif ($detail->{'status'} =~ /^[DAM]+\d*/) {
					$action="remove";
					$mode=$detail->{'mode_from'};
				}
				else {
					error "unknown status ".$detail->{'status'};
				}
				
				# test that the file mode is ok
				if ($mode !~ /^100[64][64][64]$/) {
					error sprintf(gettext("you cannot act on a file with mode %s"), $mode);
				}
				if ($action eq "change") {
					if ($detail->{'mode_from'} ne $detail->{'mode_to'}) {
						error gettext("you are not allowed to change file modes");
					}
				}
				
				# extract attachment to temp file
				if (($action eq 'add' || $action eq 'change') &&
				     ! pagetype($file)) {
					eval q{use File::Temp};
					die $@ if $@;
					my $fh;
					($fh, $path)=File::Temp::tempfile("XXXXXXXXXX", UNLINK => 1);
					if (system("git show ".$detail->{sha1_to}." > '$path'") != 0) {
						error("failed writing temp file");
					}
				}

				push @rets, {
					file => $file,
					action => $action,
					path => $path,
				};
			}
		}
	}

	return reverse @rets;
}

1

