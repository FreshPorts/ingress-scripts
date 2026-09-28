#!/usr/local/bin/perl -w
#
# Copyright (c) 1999-2026 DVL Software
#

# Fill in ports.pkgversion for ports which have none.
#
# The column was added after the fact, so every existing row is NULL until
# the port is next refreshed.  A full refresh of the tree would do it, and
# take a day.  This asks make for the one value and writes the one column.
#
# usage: set-pkgversion.pl [--dryrun] [--all] [--limit N] [--debug]
#
#   --dryrun    say what would be written, write nothing
#   --all       every port on head, not only those with no pkgversion.
#               Without this the run is resumable: stop it and start it
#               again and it carries on where it left off.
#   --limit N   stop after N ports.  For trying it on a few first.
#   --debug     print the SQL
#
# HEAD only.  make runs on the host against the freshports jail's tree, as
# refresh-listed-ports.pl does, so there is no jexec and no sudo.
#
# BEFORE RUNNING THIS ON THE WHOLE TREE, READ THIS.
#
# ports carries ports_clear_cache, an AFTER UPDATE ... FOR EACH ROW trigger
# which queues the port into cache_clearing_ports and issues NOTIFY
# port_updated.  Updating 35,000 rows therefore queues 35,000 pages for
# re-rendering -- for a column which is not displayed anywhere.
#
# So either run it when that is affordable, or disable the trigger for the
# duration and leave the caches alone:
#
#   ALTER TABLE ports DISABLE TRIGGER ports_clear_cache;
#   ... run this ...
#   ALTER TABLE ports ENABLE TRIGGER ports_clear_cache;
#
# Disabling is safe here only because nothing rendered changes.  It would
# not be safe for a refresh, which changes plenty.

use strict;
use FreshPorts::branches;
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

my $MAKE = '/usr/bin/make';   # base system make; the ports tree needs no other

my $dryrun = 0;
my $all    = 0;
my $limit  = 0;
my $debug  = 0;

if (!GetOptions('dryrun' => \$dryrun, 'all' => \$all,
                'limit=i' => \$limit, 'debug' => \$debug)) {
	exit 1;
}

#
# What make says this port builds as.  undef if make could not say, which is
# a port we leave alone rather than guess at.
#
sub PkgVersionFromMakefile {
	my $origin   = shift;
	my $portsdir = $FreshPorts::Config::JailBaseDir . $FreshPorts::Config::PortsDir;

	my $MAKEOUTPUT;
	if (!open($MAKEOUTPUT, '-|', $MAKE, '-C', "$portsdir/$origin",
	                               "PORTSDIR=$portsdir", '-V', 'PKGVERSION')) {
		return undef;
	}

	my $pkgversion = <$MAKEOUTPUT>;
	close($MAKEOUTPUT);

	return undef if (!defined($pkgversion));

	chomp($pkgversion);

	return undef if ($pkgversion eq '');

	return $pkgversion;
}

FreshPorts::Utilities::InitSyslog();

print("$0 starts\n");

my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

my $dbh = FreshPorts::Database::GetDBHandle();

my $currentBranch = $FreshPorts::Constants::HEAD;
FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

#
# ports_active names its columns one by one, so it does not have pkgversion
# until that view is recreated.  The base tables do, and element_pathname
# gives us head and the origin in one go.
#
# Going round the view means doing by hand what it does for us: element
# status 'A', or deleted ports come along too.
#
my $sql = "
  SELECT P.id        AS port_id,
         EP.pathname AS pathname
    FROM ports P,
         element E,
         element_pathname EP
   WHERE EP.element_id = P.element_id
     AND E.id          = P.element_id
     AND E.status      = 'A'
     AND EP.pathname LIKE '" . $FreshPorts::Constants::Ports_HEAD_commit . "%'";

if (!$all) {
	$sql .= "\n     AND P.pkgversion IS NULL";
}

$sql .= "\nORDER BY EP.pathname";

if ($debug) {
	print "sql = $sql\n";
}

my $sth = $dbh->prepare($sql);
$sth->execute ||
	FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

my $update = $dbh->prepare('UPDATE ports SET pkgversion = ? WHERE id = ?');

my $set     = 0;
my $skipped = 0;
my $asked   = 0;

while (my $row = $sth->fetchrow_hashref()) {
	last if ($limit && $asked >= $limit);

	$asked++;

	# Ports_HEAD_commit carries a trailing slash
	my $origin = $row->{pathname};
	$origin =~ s|^\Q$FreshPorts::Constants::Ports_HEAD_commit\E||;

	my $pkgversion = PkgVersionFromMakefile($origin);

	if (!defined($pkgversion)) {
		FreshPorts::Utilities::ReportError('warning', "$ME $origin: make said nothing; left alone", 0);
		$skipped++;
		next;
	}

	print "$ME $origin: $pkgversion\n";

	next if ($dryrun);

	$update->execute($pkgversion, $row->{port_id}) ||
		FreshPorts::Utilities::ReportError('warning', "Could not set pkgversion for $origin", 1);

	$dbh->commit();
	$set++;
}

$sth->finish();
$update->finish();

my $tally = $dryrun
	? "$ME ends: $asked ports read, $skipped make could not answer for (dry run, nothing written)"
	: "$ME ends: $set set, $skipped make could not answer for";

print $tally . "\n";
FreshPorts::Utilities::Report('info', $tally);

$dbh->commit();
$dbh->disconnect();
