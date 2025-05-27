#!/usr/local/bin/perl -w
#
# $Id: test-master-port.pl,v 1.3 2007-12-30 18:41:59 dan Exp $
#
# Copyright (c) 2001-2007 DVL Software
#
# Verify that master-port is still working.
# Sometimes it breaks. So let's keep track of it.
# This script checks the value in the database for a port for which I know the master port.
# see also test-master-port.sh which queries the Makefile.
#

use strict;

require Sys::Syslog;

use FreshPorts::db_utils;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::system_status;

use DBI;

FreshPorts::Utilities::InitSyslog();


&main;
exit;

sub CheckMasterPorts($) {
	my $dbh = shift;

	my $sth;
	my $sql;
	my $row;

	# quote everything going to the database
	$sql = "SELECT master_port FROM ports_active WHERE name = 'bacula15-client'";
	$sth = $dbh->prepare($sql);
	if (!$sth->execute())  {
		FreshPorts::Utilities::ReportError('warning', "Could not execute sql: $sql", 1);
	}
	$row = $sth->fetchrow_hashref();
	if ($row->{'master_port'} ne 'sysutils/bacula15-server') {
		FreshPorts::Utilities::ReportErrorEmail('ERR', "The master port for bacula15-client is not sysutils/bacula15-server", 1, 0);
	}
	$sth->finish();
}

#####
# Main Processing Routine
##### 

sub main {
	my $dbh;

	#
	# see if the system is online.
	# If not, exit.
	#
	my $SystemStatus = FreshPorts::SystemStatus->new();
	if (!$SystemStatus->Online()) {
		Sys::Syslog::syslog('warning', "not testing master port status: system is offline");
		exit 0;
	}

	$dbh = FreshPorts::Database::GetDBHandle($FreshPorts::Constants::DB_ConnectionType => $FreshPorts::Constants::DB_ConnectionType_ReadOnly);
	if ($dbh->{Active}) {

		CheckMasterPorts($dbh);

		$dbh->disconnect();
	}
}
