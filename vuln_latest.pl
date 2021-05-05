#!/usr/local/bin/perl -w
#
# $Id: vuln_latest.pl,v 1.12 2008-09-04 14:33:09 dan Exp $
#
# Copyright (c) 2006 DVL Software
#

use strict;

use FreshPorts::port;
use FreshPorts::database; 
use DBI;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::system_status;

require FreshPorts::config;

sub CreateVulnHTML($) {

	my $dbh = shift;
	
	my $ReportInterval = '14 days';

	umask(02);
	# create the output file name gradually, ensuring the directories exist

	my $OutputFileDir = $FreshPorts::Config::HourlySummaryDir;

	if (-d $OutputFileDir) {
		print "'$OutputFileDir' exists\n";
	} else {
		print "'$OutputFileDir' does not exist\n";
		print "   trying to mkdir '$OutputFileDir'\n";
		if (mkdir $OutputFileDir, 0775) {
		} else {
			print "Could not create directory $OutputFileDir\n";
			return 1;
		}
	}

	my $OutputFile = "$OutputFileDir/vuln-latest.html.tmp";
	print "trying to open '$OutputFile'\n";
   
	if (open(FILE, ">$OutputFile")) {
		print "that file was opened.  now writing output\n";
		my $count =0;

		my $row;
		my $query = "
  SELECT DISTINCT
         PA.category,
         PA.name AS port,
         coalesce(V.date_modified, V.date_entry, V.date_discovery) AS date,
         V.vid,
         to_char(coalesce(V.date_modified, V.date_entry, V.date_discovery)::date, 'Mon DD') AS date_formatted,
         V.date_modified IS NULL AS new,
         lower(name)
    FROM commit_log_ports_vuxml CLPV, vuxml V, ports_active PA
   WHERE CLPV.vuxml_id = V.id
     AND CLPV.port_id  = PA.id
ORDER BY coalesce(V.date_modified, V.date_entry, V.date_discovery) desc, lower(name)
   LIMIT 15";
        
		my $sth = $dbh->prepare($query);

		$sth->execute ||
			FreshPorts::Utilities::ReportError('warning', "Could not execute SQL statement\n--$query--\n... maybe invalid?", 1);

		print FILE '<table class="fullwidth">' . "\n";
		while ($row = $sth->fetchrow_hashref()) {
			print FILE '<tr><td align="left"><a href="' . $FreshPorts::Constants::VUXML_URL . $row->{vid} . '.html">' . $row->{port} . '</a>';
			if (!$row->{new}) {
				print FILE '<sup>*</sup>';
			}
			print FILE '</td>' . 
			     '<td nowrap align="right">' . $row->{date_formatted} . '</td></tr>' . "\n";
		}
		print FILE '</table>' . "\n";
		
		$query = "
  SELECT count(DISTINCT CLPV.port_id) AS ports,
         count(DISTINCT V.id)         AS vulns
    FROM commit_log_ports_vuxml CLPV, vuxml V
   WHERE CLPV.vuxml_id = V.id
     AND greatest(V.date_modified, V.date_entry, V.date_discovery)::date >= (current_date - interval '" . $ReportInterval . "')::date";

		$sth = $dbh->prepare($query);

		$sth->execute ||
			FreshPorts::Utilities::ReportError('warning', "Could not execute SQL statement\n--$query--\n... maybe invalid?", 1);
		$row = $sth->fetchrow_hashref();
		if ($row->{vulns}) {
			print FILE '<p align="center">' . $row->{vulns} . ' vulnerabilities affecting ' . $row->{ports} . ' ports have been reported in the past ' . $ReportInterval . '</p>';
		} else {
			print FILE '<p align="center">No vulnerabilities have been reported in the past ' . $ReportInterval . '</p>';
		}

		$sth->finish();


		print "closing file\n";
		close FILE;

		print "renaming '$OutputFile' to '$OutputFileDir/vuln-latest.html'\n";
		rename "$OutputFile", "$OutputFileDir/vuln-latest.html";
	} else {
		print "could not open '$OutputFile'\n";
		return 3;
	}
   
	return 0;
}


#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}


my $dbh = FreshPorts::Database::GetDBHandle();

my $return = CreateVulnHTML($dbh);

$dbh->disconnect();

exit $return;
