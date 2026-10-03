#!/usr/local/bin/perl -w
#
# $Id: fetch-refresh-ports.pl,v 1.8 2007-10-11 18:14:03 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#

use strict;
#use lib '/home/freshports.org/scripts/updates';
use FreshPorts::port;
 
use DBI;

#use lib '~/tmp/scripts';

use FreshPorts::database;
use FreshPorts::utilities;

my $dbh;

my $maxlength=0;
my $dirname='';
my $porttorefresh;
my @PORTS;
my $sql;
my $sth;
my @row;


FreshPorts::Utilities::InitSyslog();

$dbh = FreshPorts::Database::GetDBHandle();

#
# get a list of ports to update
#

$sql = "select ports.id, categories.name, element.name, needs_refresh \
        from ports, categories, element \
        where categories.id       = ports.category_id \
          and ports.element_id    = element.id
          and ports.needs_refresh <> 0";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
   print "now processing @row\n";
   push @PORTS, "$row[0]:$row[1]:$row[2]:$row[3]"
}
 
foreach $porttorefresh (@PORTS) {
	my $port_name;
	my $category_name;
	my $needs_refresh;
	my $FetchWorked;
	my $port;
	my $port_id;

	print "found $porttorefresh\n";

	($port_id, $category_name, $port_name, $needs_refresh) = split /:/,$porttorefresh, 4;

	$port = FreshPorts::Port->new($dbh);

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
		my $FetchAttempts = $FreshPorts::Config::Fetch_Retry_Limit;

		while ($FetchAttempts) {
			if (!$port->FetchFilesNeedingRefresh()) {
				$port->ExtractValuesFromMakefile();
				$port->{needs_refresh} = 0;
				$port->save();
				last;
			} else {
				# fetch failed
				# sleep, then try again
				Sys::Syslog::syslog('warning', "sleeping after fetch failed for ($port_id, $category_name, $port_name, $needs_refresh)");
				print 'fetch failed, sleeping for ' . ($FreshPorts::Config::Fetch_Retry_Limit - $FetchAttempts + 1) * $FreshPorts::Config::Fetch_Sleep_Time . "seconds...\n";
				sleep ($FreshPorts::Config::Fetch_Retry_Limit - $FetchAttempts + 1) * $FreshPorts::Config::Fetch_Sleep_Time;
				$FetchAttempts--;
			}
		}

		if (!$FetchAttempts) {
			# could not fetch those files....
			FreshPorts::Utilities::ReportError('warning', "Failed to fetch any files for port ($port_id, $category_name, $port_name, $needs_refresh)", 1);
		}
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not retrieve port ($port_id, $category_name, $port_name, $needs_refresh)", 1);
	}
}
$dbh->commit();
$dbh->disconnect();

`touch  /home/freshports.org/lastupdate`
