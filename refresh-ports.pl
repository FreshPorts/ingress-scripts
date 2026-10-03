#!/usr/local/bin/perl -w
#
# $Id: refresh-all-ports.pl,v 1.1 2013-04-24 12:21:49 dan Exp $
#
# Copyright (c) 1999-2026 Dan Langille
#

# refresh the ports listed in the ports_to_refresh table.

use strict;
use FreshPorts::branches;
use FreshPorts::port;
use DBI;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::system_status;
use Getopt::Long;

my $dbh;

my $porttorefresh;
my @PORTS;
my %Port;
my $sql;
my $sth;
my @row;

my $dryrun = 'n';
my $debug  = 'n';
my $limit  = 0;
my $offset = 0;

if (!GetOptions('debug=s' => \$debug, 'dryrun=s' => \$dryrun, 'limit=i' => \$limit, 'offset=i' => \$offset)) {
	exit;
}

if ($dryrun && $dryrun ne 'y' && $dryrun ne 'n') {
	print("--dryrun must be y or n\n");
	exit;
}

print("refresh-ports.pl starts\n");

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

$dbh = FreshPorts::Database::GetDBHandle();

my $currentBranch  = $FreshPorts::Constants::HEAD;
# start off on head
FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);


#
# get a list of ports to update
#

$sql = "SET CLIENT_ENCODING TO 'ISO-8859-1'; select PTR.port_id, categories.name as category, element.name as port
        from ports_to_refresh PTR, ports P, categories, element
        where PTR.port_id   = P.id 
          and P.category_id = categories.id 
          and P.element_id  = element.id
        order by category, port";


if ($limit) {
	$sql .= "\n        LIMIT $limit OFFSET $offset\n";
}

if ($debug eq 'y') {
	print "\$dryrun='$dryrun'\n";
	print "\$limit='$limit'\n";
	print "\$offset='$offset'\n";
	print "sql = $sql\n";
}

if ($dryrun eq 'y') {
	exit;
}

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
	print "now processing @row\n";
	$Port{id}            = $row[0];
	$Port{category}      = $row[1];
	$Port{port}          = $row[2];

	#
	# by enclosing the has in { }
	# we are creating an anonymous hash
	#
	push @PORTS, {%Port};

}
$sth->finish();


# 
# For this, we are refreshing strictly from files, and not processing a commit.
# We shall assume 'git' because the code needs a value.
#
my $port    = FreshPorts::Port->new($dbh, 'git');
my $element = FreshPorts::Element->new($dbh);

foreach $porttorefresh (@PORTS) {
	my $result;

	my $port_id       = $porttorefresh->{id};
	my $category_name = $porttorefresh->{category};
	my $port_name     = $porttorefresh->{port};

	print("refresh-ports.pl found $category_name/$port_name\n");
	
	my $refreshed = 0;

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
		$result = 0;
		$element->{id} = $port->{element_id};
		if (defined($element->FetchByID())) {
			if ($element->{status} eq $FreshPorts::Element::Deleted) {
				#
				# this port is deleted but needs refresh.
				#
				print("that port has been deleted and will not be refreshed\n");
				$result = 0;
			} else {
				$result = $port->RefreshFromFiles($FreshPorts::Constants::HEAD, 1, 0); # needs refresh, don't refresh
				print("refresh attempt done ($result)\n");
			}
		} else {
			FreshPorts::Utilities::ReportError('warning', "Could not retrieve element ($port_id, $category_name, $port_name)", 1);
		}

		if ($result == 0) {

			$port->save();

			$dbh->commit();
			
			$refreshed = 1;
		} else {
			print("update result is $result ******************************************\n");
			$dbh->rollback();
		}
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not retrieve port ($port_id, $category_name, $port_name)", 1);
	}

	if ($refreshed) {
		# delete from the table
		$sql = "delete from ports_to_refresh where port_id = $port_id";
		$sth = $dbh->prepare($sql);
		$sth->execute ||
        		die "Could not execute SQL $sql ... maybe invalid? $sql";
		$sth->finish();
		
		$dbh->commit();
	}
}

$sth->finish();

$dbh->disconnect();

print("refresh-ports.pl finishes\n");
