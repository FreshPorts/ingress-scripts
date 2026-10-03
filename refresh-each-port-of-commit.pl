#!/usr/local/bin/perl -w
#
# $Id: refresh-each-port.pl,v 1.4 2012-08-15 11:49:10 dan Exp $
#
# Copyright (c) 1999-2026 Dan Langille
#

#
# Based on what is in head now, refresh the ports mentioned in a commit
# Useful if you need to refresh ports after something in Mk is fixed,
# for example.
#


use strict;
use FreshPorts::port;
use DBI;
use FreshPorts::database;
use FreshPorts::utilities;

my $dbh;

my $porttorefresh;
my @PORTS;
my $sql;
my $sth;
my @row;
my $message_id;

sub usage {
	my $this = shift;

	print "USAGE : $0 message_id\n";
	print "   <message_id> : a message id, such as 2017001023\@repo.freebsd.org\n"
}


if (($#ARGV+1) >= 1) {
  $message_id = $ARGV[0];
} else {
  usage();
  exit 1;
}

my $currentBranch  = $FreshPorts::Constants::HEAD;

FreshPorts::Utilities::InitSyslog();

$dbh = FreshPorts::Database::GetDBHandle();

# start off on head
FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

#
# get a list of ports to update
#

$sql = "
SELECT PA.id,
       PA.category,
       PA.name
  FROM commit_log_ports CLP JOIN commit_log CL 
                              ON CLP.commit_log_id = CL.id AND
                                 CL.message_id     = '$message_id'
                            JOIN ports_active PA on PA.id = CLP.port_id
";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
#	print "now reading @row\n";
	push @PORTS, "$row[0]\t$row[1]\t$row[2]"
}

my $port = FreshPorts::Port->new($dbh);

foreach $porttorefresh (@PORTS) {
	my $result;

	print "found $porttorefresh\n";

	my ($port_id, $category_name, $port_name) = split /\t/,$porttorefresh, 3;

	$port->{id} = $port_id;
	if ($port->FetchByID()) {

		# needs_refresh = 0, and fetch_files = 0
		$result = $port->RefreshFromFiles($currentBranch, 0, 0, '');
		print "has been refreshed ($result)\n";

		if ($result == 0) {
			$port->save($currentBranch);
			$dbh->commit();
		} else {
			$dbh->rollback();
			print "update result is $result ******************************************\n";
		}
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not retrieve port ($port_id, $category_name, $port_name)", 1);
	}
}

$sth->finish();

$dbh->commit();
$dbh->disconnect();
