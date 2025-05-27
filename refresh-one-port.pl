#!/usr/local/bin/perl -w
#
# $Id: fetch-refresh-ports.pl,v 1.8 2007-10-11 18:14:03 dan Exp $
#
# Copyright (c) 2001 DVL Software
#

use strict;
#use lib '/home/freshports.org/scripts/updates';
use FreshPorts::port;
 
use DBI;

#use lib '~/tmp/scripts';

use FreshPorts::constants;
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

my $currentBranch  = $FreshPorts::Constants::HEAD;
FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

$sql = "select ports.id, categories.name, element.name \
        from ports, categories, element \
        where categories.id       = ports.category_id \
          and ports.element_id    = element.id
          and element.name = 'py-requests-kerberos' and categories.name = 'security'";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
   print "now processing @row\n";
   push @PORTS, "$row[0]:$row[1]:$row[2]"
}
 
foreach $porttorefresh (@PORTS) {
	my $port_name;
	my $category_name;
	my $FetchWorked;
	my $port;
	my $port_id;

	print "found $porttorefresh\n";

	($port_id, $category_name, $port_name) = split /:/,$porttorefresh, 4;

	$port = FreshPorts::Port->new($dbh);

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
		$port->RefreshFromFiles($FreshPorts::Constants::HEAD, 0, 0, '');
		$port->save();
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not retrieve port ($port_id, $category_name, $port_name)", 1);
	}
}
$sth->finish();
$dbh->commit();
$dbh->disconnect();
