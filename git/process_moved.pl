#!/usr/local/bin/perl -w
#
# $Id: process_moved.pl,v 1.2 2006-12-17 12:04:02 dan Exp $
#
# Copyright (c) 2001-2004 DVL Software
#
# Parse /usr/ports/MOVED and load into ports_moved table
#

#we make a great deal of use of a global variable Updates.  We should fix that up.
use strict;

require Sys::Syslog;

use FreshPorts::branches;
use FreshPorts::constants;
use FreshPorts::db_utils;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::caching;

use DBI;

FreshPorts::Utilities::InitSyslog();


&main;
exit;

sub usage {
	print "USAGE : $0 INPUTFILE\n";
}

#####
# Main Processing Routine
##### 

sub main {

	my $dbh;

	print "dbname = $FreshPorts::Config::dbname\n";

	$dbh = FreshPorts::Database::GetDBHandle();
	if ($dbh->{Active}) {

		my $currentBranch  = $FreshPorts::Constants::HEAD;

		# start off on head
		FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

		EmptyMoved($dbh);

		parsefile($dbh);

		ClearCacheFiles($dbh);

# hmmm, this might be a good way to debug...
# issue a rollback after each attempt...
#
#		$dbh->rollback();
		$dbh->commit();

		$dbh->disconnect();
	}
}

sub parsefile ($) {
	my $dbh       = shift;

	my $line;
	my $result;
	my $From;
	my $To;
	my $Date;
	my $Why;

	my $ID;

	print "reading from STDIN...\n";
	while (defined(my $line = <STDIN> ) ) {
		# remove the trailing CR/LF
		chomp $line;

		if ($line =~ /^.*\/.*\|.*\|\d{4}-\d{2}-\d{2}\|.*$/) {

			($From, $To, $Date, $Why) = $line =~ /^(.*\/.*)\|(.*)\|(\d{4}-\d{2}-\d{2})\|(.*)$/;
			$ID = AddMoved($dbh, $From, $To, $Date, $Why);
		}
	}
}

sub AddMoved($;$;$;$;$) {
	my $dbh    = shift;
	my $From   = $dbh->quote(shift);
	my $To     = $dbh->quote(shift);
	my $Date   = $dbh->quote(shift);
	my $Why    = $dbh->quote(shift);

	my $sth;
	my $sql;
	my @row;

	# quote everything going to the database
	$sql = "select PortsMovedAdd ($From, $To, $Date, $Why)";;
	$sth = $dbh->prepare($sql);
	if (!$sth->execute())  {
		FreshPorts::Utilities::ReportError('warning', "Could not execute sql: $sql", 1);
	}
	@row = $sth->fetchrow_array();   
	$sth->finish();

	return $row[0];
}


sub EmptyMoved($) {
	my $dbh = shift;

	my $sth;
	my $sql;

	# quote everything going to the database
	$sql = "DELETE FROM ports_moved";
	$sth = $dbh->prepare($sql);
	if (!$sth->execute())  {
		FreshPorts::Utilities::ReportError('warning', "Could not execute sql: $sql", 1);
	}
}

sub ClearCacheFiles($) {
	my $dbh = shift;
	my $sth;
	my $sql;
	my $updated_port;
	my $i = 0;

	$sql = '
SELECT P.id   AS port_id,
       C.name AS category,
       E.name AS port
 FROM element E, categories C, ports P 
    JOIN (SELECT from_port_id as port_id
            FROM ports_moved
	       UNION
	      SELECT to_port_id as port_id
            FROM ports_moved) as tmp on P.id = tmp.port_id
           WHERE E.id = P.element_id
             AND C.id = P.category_id
        ORDER BY category, port';

	print "sql is $sql\n";

	$sth = $dbh->prepare($sql);
	$sth->execute ||
		die "Could not execute SQL $sql ... maybe invalid?";

	my $Caching = FreshPorts::Caching->new($dbh);
	while ($updated_port = $sth->fetchrow_hashref()) {
	        $i++;
		$Caching->RemovePortFromCache($updated_port->{port_id}, $updated_port->{category}, $updated_port->{port});
	}

    return $i;
}
