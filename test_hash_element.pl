#!/usr/local/bin/perl -w
#
# $Id: test_hash_element.pl,v 1.2 2001-12-22 04:30:42 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#

use strict;
use DBI;
use FreshPorts::element;
use FreshPorts::category;
use FreshPorts::port;
use FreshPorts::database;

use File::Basename;
use Sys::Syslog;

require FreshPorts::config;

my ($dbh, $port, $name);

my %Ports;

$dbh = FreshPorts::Database::GetDBHandle();

$name = "security/acid";

print "FETCHING port = '$name'\n";


$port = FreshPorts::Port->new($dbh);
$port->{partialpathname} = $name;

$port->FetchByPartialPathName();

print "id                   = $port->{id}\n";
print "element_id           = $port->{element_id}\n";
print "category_id          = $port->{category_id}\n";

$Ports{$name} = $port;

my $name2 =  "www/w3m";
$port = FreshPorts::Port->new($dbh);
$port->{partialpathname} = $name2;

$port->FetchByPartialPathName();
$Ports{$name2} = $port;


my $newport;

$newport = $Ports{$name};

print "$name\n";
print "id                   = $port->{id}\n";
print "element_id           = $port->{element_id}\n";
print "category_id          = $port->{category_id}\n";

$port = $Ports{$name2};

print "$name2\n";
print "id                   = $port->{id}\n";
print "element_id           = $port->{element_id}\n";
print "category_id          = $port->{category_id}\n";

while (($name, $port) = each %Ports) {
        print "port = $name, port_id = '$port->{id}', category_id='$port->{category_id}'\n";
    }

$dbh->rollback();
$dbh->disconnect();
