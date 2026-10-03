#!/usr/local/bin/perl -w
#
# $Id: purge_old_password_tokens.pl,v 1.1 2010-09-17 14:31:02 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#

use strict;

use FreshPorts::database; 
use DBI;

require Sys::Syslog;
require FreshPorts::config;
use FreshPorts::system_status;

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
my $row;
my $rowcount;

#
# get a list of unrefreshed ports which have been in the db more than 10 minutes
#

$sql = "SELECT user_password_reset_purge() as rowcount";
$sth = $dbh->prepare($sql);
$sth->execute ||
        die "Could not execute SQL $sql ... maybe invalid?";

$row=$sth->fetchrow_hashref();

$rowcount = $row->{rowcount};

$sth->finish();

$dbh->commit();

$dbh->disconnect();

FreshPorts::Utilities::InitSyslog();
Sys::Syslog::syslog('notice', "number of expired password tokens purged: " . $rowcount);
