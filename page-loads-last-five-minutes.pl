#!/usr/local/bin/perl -w
#
# $Id: page-loads-last-five-minutes.pl,v 1.1 2007-02-14 22:25:42 dan Exp $
#
# Copyright (c) 1999-2006 DVL Software
#

use strict;

use DBI;
use FreshPorts::database;
#use cache;
#use commit_log_ports_ignore;
use FreshPorts::system_status;

my $dbh;
my @row;

my $DaysRefreshed;

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

$dbh = FreshPorts::Database::GetDBHandle();
if (!$dbh) {
 print "0\n";
}
my $sql = "
   SELECT COUNT(*)
     FROM page_load_detail
    WHERE date >= current_date - interval '10 minutes'
      AND to_timestamp(date || ' ' || time, 'YYYY-MM-DD HH24:MI:SS.US') BETWEEN CURRENT_TIMESTAMP - INTERVAL '5 minutes' AND CURRENT_TIMESTAMP";
   
#   print "sql is $sql\n";

my $sth = $dbh->prepare($sql);
$sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

my $msgbody = '';

if (@row = $sth->fetchrow_array) {
 print $row[0] . "\n";
}

$sth->finish();

$dbh->commit();
$dbh->disconnect();
