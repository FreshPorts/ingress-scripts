#!/usr/local/bin/perl -w
#
# Copyright (c) 2026 Dan Langille
#
# Record the physical and virtual categories over time in category_history,
# for the graph at /category-history.php (#604).  Run daily from periodic.
#
# The lists come from the ports tree:
#
#   physical  the SUBDIR entries in Makefile
#   virtual   VALID_CATEGORIES in Mk/bsd.port.mk, less the physical ones
#
# Only commits which touch one of those two files can change either list,
# so git is asked for just those, oldest first, along main's first-parent
# line.  A row is added only when the lists differ from the row before.
#
# On an empty table the whole history is walked: a few thousand commits,
# about a minute.  After that it starts from the newest commit in the
# table.  Rows are added only when the lists change, so each run looks
# again at every commit since the last change: in November 2026, two
# years of commits, about 7 s.
#
# The walk stops at ports origin/main in latest_commits.txt, the last commit
# FreshPorts has processed (see latest-commits.sh and compare-index-daily.sh),
# so the graph never runs ahead of the rest of the site.  This used to be the
# freshports/origin/main tag in the repo, which git-delta.sh no longer
# writes; see https://github.com/FreshPorts/freshports/issues/522
#
# The repo belongs to the ingress user and this runs as freshports, so
# safe.directory is given on each git command.  We only read from it.
#

use strict;

use FreshPorts::database;
use DBI;
use Time::HiRes qw(time);

require Sys::Syslog;
use FreshPorts::config;
use FreshPorts::system_status;

# --dry-run: print what would be added to an empty table; no database
my $DryRun = @ARGV && $ARGV[0] eq '--dry-run';

my $Git      = '/usr/local/bin/git';
my $Repo     = $FreshPorts::Config::BaseDirIngress . '/repos/ports';
my $Latest   = $FreshPorts::Config::BaseDirIngress . '/latest_commits/latest_commits.txt';
my $Key      = 'ports:freshports/origin/main';
my @Files    = ('Makefile', 'Mk/bsd.port.mk');

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$DryRun && !$SystemStatus->Online()) {
	exit 0;
}

FreshPorts::Utilities::InitSyslog();

sub git {
	my @args = @_;

	# git show fails when the file did not exist yet (Mk/bsd.port.mk before
	# 1994-08-21, VALID_CATEGORIES before 1999); that is an empty list, and
	# not worth the "fatal: path ... does not exist" in the periodic mail.
	my $quiet = $args[0] eq 'show';
	my $stderr;
	if ($quiet) {
		open($stderr, '>&', \*STDERR) or die "could not dup STDERR: $!";
		open(STDERR, '>', '/dev/null') or die "could not reopen STDERR: $!";
	}

	my $ok = open(my $fh, '-|', $Git, '-c', "safe.directory=$Repo", '-C', $Repo, @args);

	if ($quiet) {
		open(STDERR, '>&', $stderr) or die "could not restore STDERR: $!";
	}
	die "could not run git @args: $!" if !$ok;

	local $/;
	my $out = <$fh>;
	close($fh);
	return defined($out) ? $out : '';
}

# The words assigned to $Variable with = or +=, across continuation lines.
# Words starting with $ are make variables, not categories.
sub assigned {
	my ($Text, $Variable) = @_;

	$Text =~ s/\\\n/ /g;

	my %words;
	while ($Text =~ /^[ \t]*\Q$Variable\E[ \t]*\+?=(.*)$/mg) {
		$words{$_} = 1 foreach grep { !/^\$/ } split(' ', $1);
	}

	return \%words;
}

# the lists at one commit, as sorted array refs; virtual is undef
# before VALID_CATEGORIES existed
sub categories_at {
	my ($Commit) = @_;

	my $physical = assigned(git('show', "$Commit:Makefile"),       'SUBDIR');
	my $valid    = assigned(git('show', "$Commit:Mk/bsd.port.mk"), 'VALID_CATEGORIES');

	my @physical = sort keys %$physical;
	my $virtual  = %$valid ? [ sort grep { !$physical->{$_} } keys %$valid ] : undef;

	return (\@physical, $virtual);
}

sub same {
	my ($x, $y) = @_;

	return 1 if !defined($x) && !defined($y);
	return 0 if !defined($x) || !defined($y);
	return join(' ', @$x) eq join(' ', @$y);
}

my $Start = time();

# the last line for ports origin/main wins, as latest_commit_get does
my $End = '';
open(my $latest, '<', $Latest) or die "could not open $Latest: $!\n";
while (my $line = <$latest>) {
	chomp($line);
	my ($repo, $ref, $commit) = split(/:/, $line);
	$End = $commit if defined($commit) && "$repo:$ref" eq $Key;
}
close($latest);

die "no $Key in $Latest -- has git-delta.sh ever completed a batch?\n" if $End eq '';
die "'$End' for $Key in $Latest is not a full commit hash\n" if $End !~ /^[0-9a-f]{40}$/;

# e.g. a repo cloned again, and not yet fetched as far as the file says
my $Verified = git('rev-parse', '-q', '--verify', "$End^{commit}");
chomp($Verified);
die "'$End' for $Key in $Latest is not a commit in $Repo\n" if $Verified ne $End;

my $dbh = $DryRun ? undef : FreshPorts::Database::GetDBHandle();

# every commit which could change the lists, oldest first
my @Commits = map { [ split(' ', $_) ] }
	split("\n", git('log', '--first-parent', '--reverse', '--format=%H %cI', $End, '--', @Files));

# what we already have, so we can start after the newest of it
my $rows = $DryRun ? [] : $dbh->selectall_arrayref('SELECT commit_hash, physical, virtual FROM category_history');
my %Have = map { $_->[0] => [ $_->[1], $_->[2] ] } @$rows;

my $From     = 0;
my $Physical = undef;
my $Virtual  = undef;
for (my $i = $#Commits; $i >= 0; $i--) {
	my $have = $Have{$Commits[$i][0]};
	if ($have) {
		$From = $i + 1;
		($Physical, $Virtual) = @$have;
		last;
	}
}

if (%Have && $From == 0) {
	die "none of the " . scalar(keys %Have) . " commits in category_history are on main up to $End; not adding to it\n";
}

my $insert = $DryRun ? undef : $dbh->prepare('INSERT INTO category_history (commit_hash, commit_date, physical, virtual) VALUES (?, ?, ?, ?)');

my $Added = 0;
for (my $i = $From; $i <= $#Commits; $i++) {
	my ($commit, $date) = @{$Commits[$i]};

	my ($physical, $virtual) = categories_at($commit);

	# before the top level Makefile had any categories
	next if !@$physical;

	next if defined($Physical) && same($physical, $Physical) && same($virtual, $Virtual);

	if ($DryRun) {
		printf("%s %s %3d %s\n", $date, substr($commit, 0, 12), scalar(@$physical), defined($virtual) ? sprintf('%3d', scalar(@$virtual)) : '  -');
	} else {
		$insert->execute($commit, $date, $physical, $virtual)
			or die "could not insert $commit";
	}
	$Added++;

	($Physical, $Virtual) = ($physical, $virtual);
}

exit 0 if $DryRun;

$dbh->commit();
$dbh->disconnect();

Sys::Syslog::syslog('notice', sprintf('category_history: %d commits looked at, %d rows added, now %d physical %s virtual, %.1f s',
	scalar(@Commits) - $From, $Added,
	defined($Physical) ? scalar(@$Physical) : 0,
	defined($Virtual)  ? scalar(@$Virtual)  : 'no',
	time() - $Start));

exit 0;
