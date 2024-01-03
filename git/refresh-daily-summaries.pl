#!/usr/local/bin/perl -w
#
# $Id: refresh-daily-summaries.pl,v 1.2 2006-12-17 12:04:02 dan Exp $
#
# Copyright (c) 1999-2003 DVL Software
#

use strict;

use DBI;
use FreshPorts::database;
use FreshPorts::cache;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::system_status;

my $dbh;

my $DaysRefreshed;

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

FreshPorts::Utilities::InitSyslog();

$dbh = FreshPorts::Database::GetDBHandle();

$DaysRefreshed = FreshPorts::Cache::RefreshDailySummaries($dbh);

$dbh->rollback();

$dbh->disconnect();
