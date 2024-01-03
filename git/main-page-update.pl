#!/usr/local/bin/perl -w
#
# $Id: main-page-update.pl,v 1.11 2002-04-01 21:21:00 dan Exp $
#
# Copyright (c) 1999-2002 DVL Software
#

use strict;
#use lib "$ENV{HOME}/scripts";
use DBI;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::housekeeping;
use FreshPorts::cache;

my $dbh;

my $sql;
my $sth;
my $MaxCommitLogPortId;
my $LastCommitLogIdProcessed;
my $housekeeping;
my $MaxCommitID;
my $DaysRefreshed;

FreshPorts::Utilities::InitSyslog();

while (1) {
	print "sleeping\n";
	sleep 5;
	print "just woke up\n";

	undef $MaxCommitID;
	$DaysRefreshed = 0;

	$dbh = FreshPorts::Database::GetDBHandle();

	$housekeeping = FreshPorts::Housekeeping->new($dbh);
	$housekeeping->read();

	$MaxCommitLogPortId	= FreshPorts::Cache::GetMaxCommitLogPortId($dbh);

	if (!defined($housekeeping->{last_port_commit})) {
		print "last_port_commit was not defined\n";
		$housekeeping->{last_port_commit}	= 0;
		$housekeeping->{refresh_now}		= 1;
	}

	print "\$MaxCommitLogPortId               = '$MaxCommitLogPortId'\n";
	print "\$housekeeping->{last_port_commit} = '$housekeeping->{last_port_commit}'\n";
	print "\$housekeeping->{refresh_now}      = '$housekeeping->{refresh_now}'\n";

	if ($housekeeping->{refresh_now} || $MaxCommitLogPortId > $housekeeping->{last_port_commit}) {
		print "housekeeping shows a refresh is needed\n";
		$sql = "UPDATE housekeeping SET refresh_now = 0";
		if ($sth = $dbh->prepare($sql)) {
			if ($sth->execute) {
				print "refreshing main page now.\n";
				$MaxCommitID   = FreshPorts::Cache::RefreshMainPage($dbh);

			} else {
	            FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 0);
			}
		} else {
			FreshPorts::Utilities::ReportError('warning', "Could not prepare SQL $sql ... maybe invalid?", 0);
		}
		
	}

	if ($housekeeping->{daily_refreshes}) {
		print "daily summary needed\n";
		$DaysRefreshed = FreshPorts::Cache::RefreshDailySummaries($dbh);
	} else {
		print "daily summary not necessary\n";
	}

	$dbh->commit();
	print " done!\n";

	$dbh->disconnect();
}
