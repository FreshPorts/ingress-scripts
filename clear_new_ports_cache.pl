#!/usr/local/bin/perl -w
#
# Copyright (c) 2026 Dan Langille
#
# A port page shows NEW for 10 days after the port was added (see
# DaysMarkedAsNew in www classes/port-display.php).  The page is cached,
# and nothing cleared that cache when the 10 days ran out, so a port kept
# its NEW marker until something else, such as its next commit, cleared it.
# See https://github.com/FreshPorts/freshports/issues/464
#
# Run daily (periodic daily/238.fp_clear_new_ports_cache).  This queues the
# head ports whose NEW marker ran out in the past two days for cache
# clearing; fp-listen removes the cached pages when it gets NOTIFY
# port_updated, as it does for a commit.  Two days, not one, so a port is
# still cleared if one daily run is missed.  A port cleared twice is only
# rebuilt on its next visit.
#
# usage: clear_new_ports_cache.pl [-n]
#   -n  dry run: list the ports, change nothing, write to stdout only
#

use strict;

use Getopt::Std;
use DBI;

use FreshPorts::database;
use FreshPorts::system_status;
use FreshPorts::utilities;

require Sys::Syslog;
require FreshPorts::config;

# keep in step with DaysMarkedAsNew in the website
my $DaysMarkedAsNew = 10;

my %opts;
getopts('n', \%opts) or die "usage: $0 [-n]\n";
my $DryRun = $opts{n} ? 1 : 0;

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$DryRun && !$SystemStatus->Online()) {
	exit 0;
}

FreshPorts::Utilities::InitSyslog() if !$DryRun;

my $dbh = FreshPorts::Database::GetDBHandle();

# the head ports whose NEW marker ended between 2 days ago and now
my $where = "date_added >= now() - (\$1 + 2) * interval '1 day'
     AND date_added <  now() -  \$1      * interval '1 day'";

my $rowcount;

if ($DryRun) {
	my $sth = $dbh->prepare("SELECT category, name, date_added FROM ports_active WHERE $where ORDER BY date_added");
	$sth->execute($DaysMarkedAsNew) or die "could not list the ports: " . $dbh->errstr;
	$rowcount = 0;
	while (my $row = $sth->fetchrow_hashref()) {
		print "$row->{date_added}  $row->{category}/$row->{name}\n";
		$rowcount++;
	}
	$sth->finish();
	$dbh->rollback();
	print "dry run: $rowcount ports would be queued for cache clearing\n";
} else {
	$rowcount = $dbh->do("
INSERT INTO cache_clearing_ports (port_id, category, port)
SELECT id, category, name
  FROM ports_active
 WHERE $where
ON CONFLICT ON CONSTRAINT cache_clearing_ports_category_port_idx DO NOTHING", undef, $DaysMarkedAsNew);
	defined($rowcount) or die "could not queue the ports: " . $dbh->errstr;
	$rowcount = 0 if $rowcount eq '0E0';

	# fp-listen clears the queued ports when it is told; it reads the queue
	# only after this commits, because NOTIFY is delivered on commit
	if ($rowcount > 0) {
		$dbh->do('NOTIFY port_updated') or die 'could not notify port_updated: ' . $dbh->errstr;
	}
	$dbh->commit();

	Sys::Syslog::syslog('notice', "clear_new_ports_cache: $rowcount ports no longer new queued for cache clearing");
}

$dbh->disconnect();
