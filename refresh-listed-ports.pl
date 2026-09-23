#!/usr/local/bin/perl -w
#
# Copyright (c) 1999-2026 DVL Software
#

# Refresh each port named in a file, one category/port per line.
#
# Written for the output of compare-index.sh, which finds ports whose version
# in the database no longer matches the ports tree.
#
#   refresh-listed-ports.pl /var/db/freshports/cache/spooling/refresh.txt
#   compare-index.sh ... | refresh-listed-ports.pl -
#
# HEAD only, as process_default_versions.pl is.
#
# The ports tree has to be on main before this runs.  A refresh reads the
# Makefiles as they are on disk, so a tree left detached at some older commit
# -- which is how the ingress often leaves it -- would write those older
# versions into the database and undo the very thing this is fixing.
#
# Do NOT git pull or git fetch to satisfy that.  The ingress owns the state of
# that tree, and moving it forward underneath in-flight commit processing is
# worse than not running at all.  Leave the tree to whatever puts it back on
# main, and run this afterwards.
#

use strict;
use FreshPorts::branches;
use FreshPorts::port;
use DBI;
use FreshPorts::config;
use FreshPorts::constants;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::system_status;
use File::Basename;
use Getopt::Long;

# Report() appends the script directory, so the basename is enough to say
# which script in that directory did the talking.
my $ME = basename($0);

my $dbh;
my $sql;
my $sth;

my $dryrun = 'n';
my $debug  = 'n';

if (!GetOptions('debug=s' => \$debug, 'dryrun=s' => \$dryrun)) {
	exit;
}

if ($dryrun ne 'y' && $dryrun ne 'n') {
	print("--dryrun must be y or n\n");
	exit;
}

my $filename = shift;

if (!defined($filename)) {
	print("usage: $0 [--debug y] [--dryrun y] FILE\n");
	print("       FILE holds one category/port per line, or - for stdin\n");
	exit 1;
}

#
# Is the ports tree on main?  Returns undef when it is, and the reason why
# not when it is not, so the caller can log that reason rather than a
# generic refusal: which branch, or which commit, is the only thing worth
# having in the log.
#
# .git/HEAD is read directly rather than shelling out to git: the tree is
# owned by root, so git needs either privilege or a safe.directory exception,
# and this needs neither.  On a branch the file holds 'ref: refs/heads/
# <branch>'; detached, it holds a bare commit hash.
#
sub WhyPortsTreeIsNotOnMain {
	my $portsdir = $FreshPorts::Config::JailBaseDir . $FreshPorts::Config::PortsDir;
	my $headfile = $portsdir . '/.git/HEAD';

	my $HEAD;
	if (!open($HEAD, '<', $headfile)) {
		return "cannot read $headfile: $!";
	}

	my $ref = <$HEAD>;
	close($HEAD);

	if (!defined($ref)) {
		return "$headfile is empty";
	}

	chomp($ref);

	if ($ref eq 'ref: refs/heads/main') {
		return undef;
	}

	if ($ref =~ m|^ref: refs/heads/(.*)$|) {
		return "$portsdir is on branch '$1', not main";
	}

	return "$portsdir is detached at $ref, not on main";
}

#
# version, revision and epoch assembled the way bsd.port.mk assembles
# PKGVERSION: ${PORTVERSION}[_${PORTREVISION}][,${PORTEPOCH}], with the
# revision and the epoch left off when they are unset or zero.
#
# A NULL revision or epoch fetches as undef, hence the defined() tests.
#
sub PkgVersion {
	my $port = shift;

	my $version  = defined($port->{version})   ? $port->{version}   : '';
	my $revision = defined($port->{revision})  ? $port->{revision}  : '';
	my $epoch    = defined($port->{portepoch}) ? $port->{portepoch} : '';

	$version .= '_' . $revision if ($revision ne '' && $revision ne '0');
	$version .= ',' . $epoch    if ($epoch    ne '' && $epoch    ne '0');

	return $version;
}

my $LIST;
if ($filename eq '-') {
	$LIST = \*STDIN;
} else {
	open($LIST, '<', $filename) || die "$0: cannot read $filename: $!\n";
}

FreshPorts::Utilities::InitSyslog();

print("$0 starts\n");

my $notonmain = WhyPortsTreeIsNotOnMain();

if (defined($notonmain)) {
	#
	# Both lines are logged as well as printed.  A scheduled run which
	# refuses has to say what the tree was doing, and whoever reads that
	# in syslog needs the same warning as whoever reads it on a terminal:
	# the fix is to wait, not to move the tree.
	#
	FreshPorts::Utilities::ReportError('warning', "$ME $notonmain; refusing to refresh", 0);
	FreshPorts::Utilities::ReportError('warning', "$ME leave it to whatever returns it to main.  Do not pull or fetch.", 0);
	exit 1;
}

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

$dbh = FreshPorts::Database::GetDBHandle();

my $currentBranch = $FreshPorts::Constants::HEAD;
# start off on head
FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

$sql = "SET CLIENT_ENCODING TO 'ISO-8859-1';
        select P.id as port_id
          from element_pathname EP, ports P
         where pathname = ?
           and EP.element_id = P.element_id";

if ($debug eq 'y') {
	print "\$dryrun='$dryrun'\n";
	print "sql = $sql\n";
}

$sth = $dbh->prepare($sql);

my $refreshed = 0;
my $failed    = 0;
my $notfound  = 0;

while (my $category_port = <$LIST>) {
	chomp($category_port);

	# ignore blank lines, and comments, so a list can be annotated
	$category_port =~ s/#.*//;
	$category_port =~ s/^\s+|\s+$//g;
	next if ($category_port eq '');

	if ($category_port !~ m|^[^/]+/[^/]+$|) {
		FreshPorts::Utilities::ReportError('warning', "not a category/port: '$category_port'", 0);
		$failed++;
		next;
	}

	# Ports_HEAD_commit contains a trailing slash
	my $element_pathname = $FreshPorts::Constants::Ports_HEAD_commit . $category_port;

	print("$0 working on '$category_port' ('$element_pathname')\n");

	if ($dryrun eq 'y') {
		next;
	}

	$sth->execute($element_pathname) ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid? with '$element_pathname'", 1);

	my $row     = $sth->fetchrow_hashref();
	my $port_id = $row->{port_id};

	if (!defined($port_id)) {
		FreshPorts::Utilities::ReportError('warning', "No such port on $currentBranch: '$category_port'", 0);
		$notfound++;
		next;
	}

	print "now processing $category_port with port_id = $port_id\n";

	# We shall assume 'git' because the code needs a value.
	#
	my $port = FreshPorts::Port->new($dbh, 'git');

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
		# what the database holds now, before the Makefile is read
		my $was = PkgVersion($port);

		my $result = $port->RefreshFromFiles($currentBranch, $currentBranch);

		if ($result == 0) {
			# and what the Makefile says.  Both are printed whether or not
			# they differ: a port which comes back unchanged is worth seeing,
			# because it means the refresh was not what it needed.
			my $now = PkgVersion($port);

			# to the terminal for whoever is watching, and to syslog so the
			# scheduled runs leave a record of what they changed
			my $change = sprintf("%s %s: %s -> %s", $ME, $category_port, $was, $now);

			print $change . "\n";
			FreshPorts::Utilities::Report('info', $change);

			$port->save($currentBranch);
			# commit each port on its own, so a failure part way through
			# does not throw away the ports already done
			$dbh->commit();
			$refreshed++;
		} else {
			$dbh->rollback();
			FreshPorts::Utilities::ReportError('warning', "Could not refresh '$category_port' (result $result)", 0);
			$failed++;
		}
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not Fetch port ($category_port)", 0);
		$failed++;
	}
}

close($LIST) if ($filename ne '-');

$sth->finish();

my $tally = "$ME ends: $refreshed refreshed, $failed failed, $notfound not found";

print $tally . "\n";
FreshPorts::Utilities::Report('info', $tally);

$dbh->commit();
$dbh->disconnect();
