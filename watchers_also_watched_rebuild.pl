#!/usr/local/bin/perl -w
#
# Copyright (c) 2026 Dan Langille
#
# Rebuild watchers_also_watched, the precomputed
# "People watching this port, also watch:" list.
# Run nightly from periodic.
#

use strict;

use FreshPorts::database;
use DBI;
use Time::HiRes qw(time);

require Sys::Syslog;
require FreshPorts::config;
use FreshPorts::system_status;

# elements recomputed per transaction
my $BatchSize = 500;

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

my $dbh = FreshPorts::Database::GetDBHandle();

my $Start = time();

my ($queued) = $dbh->selectrow_array('SELECT watchers_also_watched_rebuild_start()');
my ($excluded) = $dbh->selectrow_array('SELECT count(*) FROM watchers_also_watched_excluded_lists');
$dbh->commit();

my $done = 0;
my $sth = $dbh->prepare('SELECT watchers_also_watched_rebuild_batch(?)');
while (1) {
	$sth->execute($BatchSize) ||
		die "Could not execute watchers_also_watched_rebuild_batch";
	my ($n) = $sth->fetchrow_array();
	$sth->finish();
	$dbh->commit();
	last if !$n;
	$done += $n;
}

# rebuild_batch() also returns 0 when another rebuild holds the lock
my ($remaining) = $dbh->selectrow_array('SELECT count(*) FROM watchers_also_watched_queue');
$dbh->commit();

$dbh->disconnect();

FreshPorts::Utilities::InitSyslog();
Sys::Syslog::syslog('notice', sprintf('watchers_also_watched rebuilt: %d of %d elements in %.1f s, %d lists excluded, %d left in queue',
	$done, $queued, time() - $Start, $excluded, $remaining));

exit($remaining ? 1 : 0);
