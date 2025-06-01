#!/usr/local/bin/perl -w
#
# $Id: refresh-all-ports.pl,v 1.1 2013-04-24 12:21:49 dan Exp $
#
# Copyright (c) 1999-2021 DVL Software
#

# When Mk/bsd.default-versions.mk changes, invoke this script
# It will take care of any required updates.
#
# NOTE this script assumes HEAD.
# so does special_processing_files::Eat which sets this file up for execution.
#
# re: https://github.com/FreshPorts/freshports/issues/509
#

use strict;
use FreshPorts::branches;
use FreshPorts::port;
use DBI;
use FreshPorts::config;
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

if (!GetOptions('debug=s' => \$debug, 'dryrun=s' => \$dryrun)) {
	exit;
}

if ($dryrun && $dryrun ne 'y' && $dryrun ne 'n') {
	print("--dryrun must be y or n\n");
	exit;
}

print("$0 starts\n");

#
# We remove this script when we start so we don't error out and start looping
# It seems the easiest way.
#
print("removing $FreshPorts::Config::DefaultVersionsFlag\n");
unlink $FreshPorts::Config::DefaultVersionsFlag;

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

$sql = "SET CLIENT_ENCODING TO 'ISO-8859-1';
        select P.id as port_id
          from element_pathname EP, ports P
         where pathname = ?
           and EP.element_id = P.element_id";


if ($debug eq 'y') {
	print "\$dryrun='$dryrun'\n";
	print "sql = $sql\n";
}

if ($dryrun eq 'y') {
	exit;
}

my $category_port;
my $row;

$sth = $dbh->prepare($sql);
$sth->execute($category_port) ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

foreach my $category_port (values %FreshPorts::Constants::PortsAffectedByDefaultVersions) {

	# Ports_HEAD_commit contains a trailing slash
	my $element_pathname = $FreshPorts::Constants::Ports_HEAD_commit . $category_port;
	print("$0 working on '$category_port' ('$element_pathname')\n");
	

	$sth->execute($element_pathname) ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid? with '$element_pathname'", 1);

	$row = $sth->fetchrow_hashref();
	my $port_id = $row->{port_id};
	print "now processing $category_port with port_id = $port_id\n";

	# We shall assume 'git' because the code needs a value.
	#
	my $port = FreshPorts::Port->new($dbh, 'git');

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
		$port->RefreshFromFiles($FreshPorts::Constants::HEAD, 0, 0, '');
		$port->save($FreshPorts::Constants::HEAD);
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not Fetch port ($category_port)", 1);
	}

}

$sth->finish();

$dbh->commit();
$dbh->disconnect();

# Still trying to avoid:
#
# May 29 11:54:10 dvl-ingress01 freshports[34063]: DBI db handle 0x19ffb9332258 has 1 uncleared child handles during global destruction.
# May 29 11:54:10 dvl-ingress01 freshports[34063]:     dbih_clearcom (dbh 0x19ffb9332258, com 0x19ffb90b6c80, imp DBD::Pg::db):
# May 29 11:54:10 dvl-ingress01 freshports[34063]:        FLAGS 0x500111: COMSET Warn PrintError PrintWarn 
# May 29 11:54:10 dvl-ingress01 freshports[34063]:        PARENT undef
# May 29 11:54:10 dvl-ingress01 freshports[34063]:        KIDS 1 (0 Active)
#
undef $dbh;

print("$0 finishes\n");
