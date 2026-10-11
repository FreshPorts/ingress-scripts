#!/usr/local/bin/perl -w
#
# $Id: refresh-all-ports.pl,v 1.1 2013-04-24 12:21:49 dan Exp $
#
# Copyright (c) 1999-2026 Dan Langille
#

# When Mk/bsd.default-versions.mk changes, invoke this script
# It will take care of any required updates.
#
# NOTE this script assumes HEAD.
# so does special_processing_files::Eat which sets this file up for execution.
#
# re: https://github.com/FreshPorts/freshports/issues/509
# re: multiple queued commits - https://github.com/FreshPorts/freshports/issues/659
#

use strict;
use FreshPorts::branches;
use FreshPorts::port;
use DBI;
use FreshPorts::config;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::system_status;
use Getopt::Long;
use Sys::Syslog;

my $dbh;

my $sql;
my $sth;

my $dryrun = 'n';
my $debug  = 'n';

if (!GetOptions('debug=s' => \$debug, 'dryrun=s' => \$dryrun)) {
	exit;
}

if ($dryrun && $dryrun ne 'y' && $dryrun ne 'n') {
	print("--dryrun must be y or n\n");
	exit;
}

print("$0 starts\n");

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

#
# Find all queued per-commit flag files.
#
# special_processing_files.pm now creates one of these per commit that
# touches Mk/bsd.default-versions.mk, named:
#
#     $FreshPorts::Config::DefaultVersionsFlag.<timestamp>.<revision>
#
# in addition to touching the master $FreshPorts::Config::DefaultVersionsFlag
# file that job-waiting.pl watches for, and $FreshPorts::Config::JobWaiting.
#
my @FlagFiles = glob("$FreshPorts::Config::DefaultVersionsFlag.*");

# ASSUMPTION: filenames look like DefaultVersionsFlag.<ts>.<revision>, e.g.
#   DefaultVersionsFlag.1757520000.a1b2c3d4e5f6...
# and the revision portion contains no further dots. If the real naming
# differs (e.g. short vs long SHA, extra separators), adjust this regex.
my $FlagFileRegex = qr/^\Q$FreshPorts::Config::DefaultVersionsFlag\E\.(\d+)\.(.+)$/;

my @Commits;
foreach my $flagfile (@FlagFiles) {
	if ($flagfile =~ $FlagFileRegex) {
		push @Commits, { ts => $1, revision => $2, flagfile => $flagfile };
	} else {
		print("skipping unrecognised flag file: $flagfile\n");
	}
}

# process oldest queued commit first
@Commits = sort { $a->{ts} <=> $b->{ts} } @Commits;

if (!@Commits) {
	print("no per-commit flag files found, nothing to do\n");
	unlink $FreshPorts::Config::DefaultVersionsFlag;
	print("$0 finishes\n");
	exit 0;
}

#
# We remove the master signal file now so we don't error out and start
# looping. Any commit that lands while we're processing will touch it again
# via special_processing_files.pm and leave its own per-commit flag file
# behind, which the next run of this script will pick up.
#
print("removing $FreshPorts::Config::DefaultVersionsFlag\n");
unlink $FreshPorts::Config::DefaultVersionsFlag;

$dbh = FreshPorts::Database::GetDBHandle();

my $currentBranch = $FreshPorts::Constants::HEAD;
# start off on head
FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

if ($debug eq 'y') {
	print "\$dryrun='$dryrun'\n";
	print "queued commits: " . join(', ', map { $_->{revision} } @Commits) . "\n";
}

if ($dryrun eq 'y') {
	exit;
}

#
# For each queued commit, find out which *_DEFAULT variables actually
# changed value, via our Python diff-parser.
#
# detect_default_version_changes.py's real interface (confirmed from the
# script itself):
#     detect_default_version_changes.py --commit <sha> --repo <path> --output <json-path>
# It exits 0 as long as the check *ran* (not as a signal that something
# changed), and always tries to write --output, even on failure, so we read
# the JSON file rather than relying solely on the exit code. The JSON has a
# top-level "changed" array of variable names and an "anomalies" array we
# should at least log.
#

use JSON::PP;

my $DetectScript = "$FreshPorts::Config::ScriptDir/detect_default_version_changes.py";
my $PortsRepo     = "$FreshPorts::Config::JailBaseDir/$FreshPorts::Constants::UsualPortsTreeLocation";
my $WorkDir       = $FreshPorts::Config::TMP;

my %VariablesChanged;   # dedup set of variable names across all queued commits

foreach my $commit (@Commits) {
	my $revision = $commit->{revision};
	my $flagfile = $commit->{flagfile};
	my $outfile  = "$WorkDir/default-version-changes.$revision.json";

	print("processing commit $revision (flag file $flagfile)\n");
	Sys::Syslog::syslog('notice', "processing default-versions commit $revision");

	my $rc = system('python3', $DetectScript,
		'--commit', $revision,
		'--repo',   $PortsRepo,
		'--output', $outfile);

	if ($rc != 0) {
		FreshPorts::Utilities::ReportError('warning',
			"detect_default_version_changes.py failed (exit $rc) for commit $revision", 1);
		# fall through -- still try to read whatever it managed to write,
		# since it writes a best-effort error JSON on failure too
	}

	if (open(my $fh, '<', $outfile)) {
		local $/;
		my $json_text = <$fh>;
		close($fh);

		my $result = eval { decode_json($json_text) };
		if (!$result) {
			FreshPorts::Utilities::ReportError('warning',
				"could not parse JSON from $outfile for commit $revision", 1);
		} else {
			if ($result->{error}) {
				FreshPorts::Utilities::ReportError('warning',
					"detect_default_version_changes.py reported an error for $revision: $result->{error}", 1);
			}

			my @changed = @{ $result->{changed} || [] };
			if (@changed) {
				print("  commit $revision changed: @changed\n");
				$VariablesChanged{$_} = 1 foreach @changed;
			} else {
				print("  commit $revision touched the file but no *_DEFAULT value changed\n");
			}

			my @anomalies = @{ $result->{anomalies} || [] };
			if (@anomalies) {
				FreshPorts::Utilities::ReportError('warning',
					"anomalies detected for commit $revision on: " . join(', ', @anomalies), 1);
			}
		}
	} else {
		FreshPorts::Utilities::ReportError('warning',
			"could not open output file $outfile for commit $revision: $!", 1);
	}

	unlink $outfile;

	# this commit is dealt with - remove its flag file so it isn't reprocessed
	unlink $flagfile;
}

if (!%VariablesChanged) {
	print("no *_DEFAULT variables changed value across queued commits, nothing further to do\n");
	$dbh->disconnect();
	print("$0 finishes\n");
	exit 0;
}

print("variables changed this run: " . join(', ', sort keys %VariablesChanged) . "\n");

#
# Pull the list of ports that depend on each changed variable from the
# database (populated by sync_port_default_version_variable.py), rather than
# the old hardcoded %FreshPorts::Constants::PortsAffectedByDefaultVersions.
#
# port_default_version_variable only stores rows for ports that DO depend on
# the variable (status = 'depends' or 'depends_error' -- an absent row means
# independent, per the table's own comment), so both statuses count here;
# there's nothing to filter out.
#
$sql = "select distinct PDVV.port_id
          from port_default_version_variable PDVV,
               default_version_variable DVV
         where PDVV.default_version_variable_id = DVV.id
           and DVV.name = ?";

$sth = $dbh->prepare($sql);

my %PortsToRefresh;   # dedup port_id across all changed variables

foreach my $variable_name (sort keys %VariablesChanged) {
	$sth->execute($variable_name) ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql for '$variable_name'", 1);

	while (my $row = $sth->fetchrow_hashref()) {
		$PortsToRefresh{$row->{port_id}} = 1;
	}
}

$sth->finish();

print("ports to refresh: " . join(', ', sort { $a <=> $b } keys %PortsToRefresh) . "\n");

#
# Refresh each affected port - same logic as before, just driven by the
# dynamic port list instead of the hardcoded hash.
#
foreach my $port_id (sort { $a <=> $b } keys %PortsToRefresh) {

	print("now processing port_id = $port_id\n");

	# We shall assume 'git' because the code needs a value.
	my $port = FreshPorts::Port->new($dbh, 'git');

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
		$port->RefreshFromFiles($FreshPorts::Constants::HEAD, 0, 0, '');
		$port->save($FreshPorts::Constants::HEAD);
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not Fetch port (port_id $port_id)", 1);
	}
}

$dbh->commit();
$dbh->disconnect();

# Still trying to avoid:
#
# May 29 11:54:10 dvl-ingress01 freshports[34063]: DBI db handle 0x19ffb9332258 has 1 uncleared child handles during global destruction.
# May 29 11:54:10 dvl-ingress01 freshports[34063]:     dbih_clearcom (dbh 0x19ffb9332258, com 0x19ffb90b6c80, imp DBD::Pg::db):
# May 29 11:54:10 dvl-ingress01 freshports[34063]:        FLAGS 0x500111: COMSET Warn PrintError PrintWarn 
# May 29 11:54:10 dvl-ingress01 freshports[34063]:        PARENT undef
# May 29 11:54:10 dvl-ingress01 freshports[34063]:        KIDS 1 (0 Active)
#
undef $dbh;

print("$0 finishes\n");
