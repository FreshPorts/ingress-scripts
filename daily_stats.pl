#!/usr/local/bin/perl -w
#
# $Id: daily_stats.pl,v 1.2 2006-12-17 12:04:00 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#

use strict;

use FreshPorts::port;
use FreshPorts::database;
use DBI;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::system_status;

require FreshPorts::config;

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

my $dbh = FreshPorts::Database::GetDBHandle();

my $sql;
my $sth;

$sql = "select DailyStatsCaculate()";

$sth = $dbh->prepare($sql);
$sth->execute ||
        die "Could not execute SQL $sql ... maybe invalid?";

$sth->fetchrow_array;

$sth->finish();
$dbh->commit();
$dbh->disconnect();
