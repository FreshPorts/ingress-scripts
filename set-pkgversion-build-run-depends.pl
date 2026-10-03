#!/usr/local/bin/perl -w
#
# Copyright (c) 1999-2026 Dan Langille
#

# Fill in ports.pkgversion and ports.build_run_depends, and the 'A' (build
# And run) rows in port_dependencies which come from the latter.
#
# Both columns were added after the fact, so every existing row is NULL until
# the port is next refreshed.  A full refresh of the tree would do it, and
# take a day.  This asks make for the two values and writes only those.
#
# usage: set-pkgversion-build-run-depends.pl [--dryrun] [--from ORIGIN]
#                                            [--limit N] [--debug]
#
#   --dryrun       say what would be written, write nothing
#   --from ORIGIN  start at this origin (e.g. lang/perl5.40), skipping those
#                  before it.  For resuming a run which was stopped.
#   --limit N      stop after N ports.  For trying it on a few first.
#   --debug        print the SQL
#
# Unlike set-pkgversion.pl, this run cannot resume by looking for NULLs:
# most ports have no BUILD_RUN_DEPENDS, and empty is stored as NULL, so a
# port which has been done looks the same as one which has not.  Every port
# on head is asked.  Each origin is printed as it is done; to resume, give
# the last one printed to --from.
#
# A port is written only when what make says differs from what is stored, so
# a second run over the same tree writes nothing.
#
# HEAD only.  make runs on the host against the freshports jail's tree, as
# refresh-listed-ports.pl does, so there is no jexec and no sudo.
#
# CACHE CLEARING: LEAVE THE TRIGGERS ON.
#
# set-pkgversion.pl suggests disabling ports_clear_cache because pkgversion
# is not displayed.  build_run_depends is: the port page shows it, and
# subtracts it from BUILD_DEPENDS and RUN_DEPENDS.  So does the 'A' section of
# each dependency's "required by" list.  Every port changed here has stale
# pages, and the queued re-rendering is wanted.
#
# port_dependencies carries cache-clearing triggers on INSERT and DELETE, so
# the dependencies' pages are queued too.

use strict;
use FreshPorts::branches;
use DBI;
use FreshPorts::config;
use FreshPorts::constants;
use FreshPorts::database;
use FreshPorts::port;
use FreshPorts::utilities;
use FreshPorts::system_status;
use File::Basename;
use Getopt::Long;

# Report() appends the script directory, so the basename is enough to say
# which script in that directory did the talking.
my $ME = basename($0);

my $MAKE = '/usr/bin/make';   # base system make; the ports tree needs no other

my $dryrun = 0;
my $from   = '';
my $limit  = 0;
my $debug  = 0;

if (!GetOptions('dryrun' => \$dryrun, 'from=s' => \$from,
                'limit=i' => \$limit, 'debug' => \$debug)) {
	exit 1;
}

#
# What make says this port builds as, and its BUILD_RUN_DEPENDS.  An empty
# list if make could not say, which is a port we leave alone rather than
# guess at.  PKGVERSION is never empty for a port make understands, so it is
# what tells us make worked; BUILD_RUN_DEPENDS is often empty, legitimately.
#
sub ValuesFromMakefile {
	my $origin   = shift;
	my $portsdir = $FreshPorts::Config::JailBaseDir . $FreshPorts::Config::PortsDir;

	my $MAKEOUTPUT;
	if (!open($MAKEOUTPUT, '-|', $MAKE, '-C', "$portsdir/$origin",
	                               "PORTSDIR=$portsdir",
	                               '-V', 'PKGVERSION', '-V', 'BUILD_RUN_DEPENDS')) {
		return ();
	}

	my $pkgversion      = <$MAKEOUTPUT>;
	my $buildrundepends = <$MAKEOUTPUT>;
	close($MAKEOUTPUT);

	return () if ($? != 0 || !defined($pkgversion));

	chomp($pkgversion);

	return () if ($pkgversion eq '');

	$buildrundepends = '' if (!defined($buildrundepends));
	chomp($buildrundepends);

	# as FreshPorts::Port does, so what we store matches what a refresh stores
	$buildrundepends = FreshPorts::Utilities::trim_multiple_to_single(FreshPorts::Utilities::trim($buildrundepends));

	return ($pkgversion, $buildrundepends);
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
# ports_active names its columns one by one, so it may not have the new
# columns until that view is recreated.  The base tables do, and
# element_pathname gives us head and the origin in one go.
#
# Going round the view means doing by hand what it does for us: element
# status 'A', or deleted ports come along too.
#
my $sql = "
  SELECT P.id                AS port_id,
         EP.pathname         AS pathname,
         P.pkgversion        AS pkgversion,
         P.build_run_depends AS build_run_depends
    FROM ports P,
         element E,
         element_pathname EP
   WHERE EP.element_id = P.element_id
     AND E.id          = P.element_id
     AND E.status      = 'A'
     AND EP.pathname LIKE '" . $FreshPorts::Constants::Ports_HEAD_commit . "%'";

if ($from ne '') {
	$sql .= "\n     AND EP.pathname >= " . $dbh->quote($FreshPorts::Constants::Ports_HEAD_commit . $from);
}

$sql .= "\nORDER BY EP.pathname";

if ($debug) {
	print "sql = $sql\n";
}

my $sth = $dbh->prepare($sql);
$sth->execute ||
	FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

my $update     = $dbh->prepare('UPDATE ports SET pkgversion = ?, build_run_depends = ? WHERE id = ?');
my $delete_bra = $dbh->prepare("DELETE FROM port_dependencies WHERE port_id = ? AND dependency_type = 'A'");

my $set       = 0;
my $unchanged = 0;
my $skipped   = 0;
my $asked     = 0;

while (my $row = $sth->fetchrow_hashref()) {
	last if ($limit && $asked >= $limit);

	$asked++;

	# Ports_HEAD_commit carries a trailing slash
	my $origin = $row->{pathname};
	$origin =~ s|^\Q$FreshPorts::Constants::Ports_HEAD_commit\E||;

	my ($pkgversion, $buildrundepends) = ValuesFromMakefile($origin);

	if (!defined($pkgversion)) {
		FreshPorts::Utilities::ReportError('warning', "$ME $origin: make said nothing; left alone", 0);
		$skipped++;
		next;
	}

	# empty is stored as NULL, as NULLIfEmpty does in FreshPorts::Port
	my $stored_pkgversion      = defined($row->{pkgversion})        ? $row->{pkgversion}        : '';
	my $stored_buildrundepends = defined($row->{build_run_depends}) ? $row->{build_run_depends} : '';

	my $pkgversion_changed      = $pkgversion      ne $stored_pkgversion;
	my $buildrundepends_changed = $buildrundepends ne $stored_buildrundepends;

	if (!$pkgversion_changed && !$buildrundepends_changed) {
		print "$ME $origin: unchanged\n";
		$unchanged++;
		next;
	}

	print "$ME $origin: pkgversion '$pkgversion' build_run_depends '$buildrundepends'\n";

	next if ($dryrun);

	$update->execute($pkgversion,
	                 $buildrundepends eq '' ? undef : $buildrundepends,
	                 $row->{port_id}) ||
		FreshPorts::Utilities::ReportError('warning', "Could not set pkgversion/build_run_depends for $origin", 1);

	#
	# Replace only the 'A' rows.  The other types came from the last refresh
	# and are not ours to touch.  update_depends_helper does the parsing, so
	# the rows are exactly what a refresh would write.
	#
	if ($buildrundepends_changed) {
		$delete_bra->execute($row->{port_id}) ||
			FreshPorts::Utilities::ReportError('warning', "Could not delete 'A' port_dependencies for $origin", 1);

		my ($category, $name) = split(m|/|, $origin, 2);

		my $port = FreshPorts::Port->new($dbh);
		$port->{id}       = $row->{port_id};
		$port->{category} = $category;
		$port->{name}     = $name;
		$port->update_depends_helper($currentBranch, $buildrundepends, 'A');
	}

	$dbh->commit();
	$set++;
}

$sth->finish();
$update->finish();
$delete_bra->finish();

my $tally = $dryrun
	? "$ME ends: $asked ports read, $unchanged unchanged, $skipped make could not answer for (dry run, nothing written)"
	: "$ME ends: $set set, $unchanged unchanged, $skipped make could not answer for";

print $tally . "\n";
FreshPorts::Utilities::Report('info', $tally);

$dbh->commit();
$dbh->disconnect();
