#!/usr/local/bin/perl -w
#
# $Id: daily_rendering_times.pl,v 1.2 2006-12-17 12:04:00 dan Exp $
#
# Copyright (c) 2004-2026 Dan Langille
#

use strict;

use FreshPorts::port;
use FreshPorts::database; 
use DBI;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::system_status;

require FreshPorts::config;

my $date;

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

if (($#ARGV+1) >= 1) {
	$date = $ARGV[0];
} else {
	print "USAGE : $0 date\n";
	exit 1;
}


my $dbh = FreshPorts::Database::GetDBHandle();

my $sql;
my $sth;

$sql = "select PageLoadSummaryUpdate('$date')";
$sth = $dbh->prepare($sql);
$sth->execute ||
        die "Could not execute SQL $sql ... maybe invalid?";

$sth->fetchrow_array;

$sql = "delete from page_load_detail where date < ('$date'::date - interval '7 days')::date";
$sth = $dbh->prepare($sql);
$sth->execute ||
        die "Could not execute SQL $sql ... maybe invalid?";

$sth->finish();

$dbh->commit();
$dbh->disconnect();
