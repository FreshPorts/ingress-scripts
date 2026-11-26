#!/usr/local/bin/perl -w
#
# Copyright (c) 2026 Dan Langille
#
# Keep supported_releases up to date: the FreeBSD branches which are
# supported right now (https://github.com/FreshPorts/periodics/issues/2).
# Run daily from periodic daily/237.fp_supported_releases.  By hand, as
# freshports:
#
#   cd /usr/local/libexec/freshports && perl supported_releases_update.pl [--dry-run]
#
# Two sources, both plain text fetched from GitHub:
#
#   stable/N and releng/N.M: the supported releases table in freebsd-doc
#   website/content/en/security/_index.adoc, the source of
#   https://www.freebsd.org/security/#sup.  Its rows look like
#
#     |stable/15 |n/a |n/a |{rel-latest-eol}
#     |releng/15.1 |15.1-RELEASE |{rel151-current-date} |{rel151-eol}
#
#   Only the first column is used.  The dates are asciidoc attributes
#   defined elsewhere in freebsd-doc, so they are not read.
#
#   CURRENT, stored as branch main: REVISION in freebsd-src main
#   sys/conf/newvers.sh, where BRANCH is "CURRENT".  CURRENT is not on the
#   security page.  Nor is it always the highest stable/N + 1: when a new
#   stable/ branch is cut, main moves up at once, but the security page
#   lists the new branch only from its .0 release.
#
# The table is made to match: new branches are added, branches no longer
# listed are removed, and main's major is updated when it moves.  Each
# change is printed, so it shows up in the daily periodic mail, and logged.
# A run which changes nothing prints nothing.
#
# Nothing is changed unless both files are fetched and pass the checks in
# wanted().  A failed fetch, or a change in the format of either file,
# leaves the table as it is and exits non-zero, so periodic reports it.
#
# --dry-run fetches and checks both files and prints what the table should
# hold.  It does not touch the database or syslog.
#

use strict;

use Getopt::Long;
use Time::HiRes qw(time);

use FreshPorts::database;
use DBI;

require Sys::Syslog;
use FreshPorts::config;
use FreshPorts::system_status;

my $SecurityPage = 'https://raw.githubusercontent.com/freebsd/freebsd-doc/main/website/content/en/security/_index.adoc';
my $NewVers      = 'https://raw.githubusercontent.com/freebsd/freebsd-src/main/sys/conf/newvers.sh';

my $Fetch        = '/usr/bin/fetch';
my $FetchTimeout = 60;

my $DryRun = 0;
GetOptions('dry-run' => \$DryRun)
	or die "usage: $0 [--dry-run]\n";

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$DryRun && !$SystemStatus->Online()) {
	exit 0;
}

FreshPorts::Utilities::InitSyslog() if !$DryRun;

sub fetch_url {
	my ($Url) = @_;

	open(my $fh, '-|', $Fetch, '-q', '-T', $FetchTimeout, '-o', '-', $Url)
		or die "could not run $Fetch: $!\n";
	my $text = do { local $/; <$fh> };
	close($fh) or die "fetch $Url failed: exit status " . ($? >> 8) . "\n";
	die "fetch $Url returned nothing\n" if !defined($text) || $text eq '';

	return $text;
}

#
# What the table should hold: branch => [ major, minor ], minor undef for
# main and stable/N.  Dies, naming what was wrong, if either file is not
# what we expect.
#
sub wanted {
	my %Want;

	my $page = fetch_url($SecurityPage);
	my $stable_max;
	my ($stables, $relengs) = (0, 0);
	while ($page =~ /^\|\s*((stable|releng)\/[^\s|]*)\s*\|/mg) {
		my ($branch, $kind) = ($1, $2);

		my ($major, $minor);
		if ($branch =~ /^stable\/(\d+)$/) {
			$major = $1;
			$stables++;
			$stable_max = $major if !defined($stable_max) || $major > $stable_max;
		} elsif ($branch =~ /^releng\/(\d+)\.(\d+)$/) {
			($major, $minor) = ($1, $2);
			$relengs++;
		} else {
			die "unexpected branch '$branch' in $SecurityPage\n";
		}

		die "$branch is listed twice in $SecurityPage\n" if exists $Want{$branch};
		$Want{$branch} = [ $major, $minor ];
	}

	# The page always lists at least one of each.  Fewer means the table
	# has moved or changed shape, not that FreeBSD has no releases.
	die "no stable/ branches found in $SecurityPage\n" if !$stables;
	die "no releng/ branches found in $SecurityPage\n" if !$relengs;

	my $newvers = fetch_url($NewVers);
	my ($revision) = $newvers =~ /^REVISION="([^"]*)"/m;
	my ($branch)   = $newvers =~ /^BRANCH="([^"]*)"/m;
	die "no REVISION in $NewVers\n" if !defined($revision);
	die "no BRANCH in $NewVers\n"   if !defined($branch);
	die "BRANCH is '$branch', not CURRENT, in $NewVers\n" if $branch ne 'CURRENT';
	die "REVISION '$revision' in $NewVers is not N.0\n"   if $revision !~ /^(\d+)\.0$/;
	my $current = $1;
	die "main is $current, but $SecurityPage lists stable/$stable_max\n" if $current <= $stable_max;

	$Want{'main'} = [ $current, undef ];

	return \%Want;
}

# main first, then newest to oldest, stable/N ahead of its releng/N.M,
# as the security page lists them
sub by_release {
	my ($Rows) = @_;

	return sort {
		$Rows->{$b}[0] <=> $Rows->{$a}[0]
		|| (defined($Rows->{$a}[1]) <=> defined($Rows->{$b}[1]))
		|| (defined($Rows->{$a}[1]) ? $Rows->{$b}[1] <=> $Rows->{$a}[1] : 0)
	} keys %$Rows;
}

sub show_minor {
	my ($minor) = @_;

	return defined($minor) ? $minor : '-';
}

my $Start = time();

my $Want = wanted();

if ($DryRun) {
	printf("%-12s %5s %5s\n", 'branch', 'major', 'minor');
	foreach my $branch (by_release($Want)) {
		printf("%-12s %5d %5s\n", $branch, $Want->{$branch}[0], show_minor($Want->{$branch}[1]));
	}
	exit 0;
}

my $dbh = FreshPorts::Database::GetDBHandle();

my %Have;
my $sth = $dbh->prepare('SELECT branch, major, minor FROM supported_releases');
$sth->execute() or die 'could not read supported_releases';
while (my ($branch, $major, $minor) = $sth->fetchrow_array()) {
	$Have{$branch} = [ $major, $minor ];
}
$sth->finish();

my $insert = $dbh->prepare('INSERT INTO supported_releases (branch, major, minor) VALUES (?, ?, ?)');
my $update = $dbh->prepare('UPDATE supported_releases SET major = ?, minor = ? WHERE branch = ?');
my $delete = $dbh->prepare('DELETE FROM supported_releases WHERE branch = ?');

my @Changes;

foreach my $branch (by_release($Want)) {
	my ($major, $minor) = @{$Want->{$branch}};
	my $have = $Have{$branch};

	if (!$have) {
		$insert->execute($branch, $major, $minor) or die "could not add $branch";
		push(@Changes, "added $branch");
	} elsif ($have->[0] != $major || show_minor($have->[1]) ne show_minor($minor)) {
		$update->execute($major, $minor, $branch) or die "could not update $branch";
		push(@Changes, sprintf('%s: major %d -> %d', $branch, $have->[0], $major));
	}
}

foreach my $branch (by_release(\%Have)) {
	next if $Want->{$branch};

	$delete->execute($branch) or die "could not remove $branch";
	push(@Changes, "removed $branch");
}

$dbh->commit();
$dbh->disconnect();

foreach my $change (@Changes) {
	print "supported_releases: $change\n";
	Sys::Syslog::syslog('notice', "supported_releases: $change");
}

Sys::Syslog::syslog('notice', sprintf('supported_releases: %d branches, %d changes, %.1f s',
	scalar(keys %$Want), scalar(@Changes), time() - $Start));

exit 0;
