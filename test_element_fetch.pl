#!/usr/local/bin/perl -w
#
# $Id: test_element_fetch.pl,v 1.4 2001-12-22 04:30:41 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#

use strict;
use DBI;
use FreshPorts::element;

require FreshPorts::config;
require FreshPorts::database;

my ($dbh, $element);

$dbh = FreshPorts::Database::GetDBHandle();

$element = FreshPorts::Element->new($dbh);
$element->{id} = 4234908243;
$element->FetchByID();

print "id                   = $element->{id}\n";
print "name                 = $element->{name}\n";
print "parent_id            = $element->{parent_id}\n";
print "directory_file_flag  = $element->{directory_file_flag}\n";
print "status               = $element->{status}\n";
print "pathname             = $element->{pathname}\n";
$element = FreshPorts::Element->new($dbh);

$element->{pathname} = '/ports/pkg/COMMENT';
$element->FetchByName();

print "id                   = $element->{id}\n";
print "name                 = $element->{name}\n";
print "parent_id            = $element->{parent_id}\n";
print "directory_file_flag  = $element->{directory_file_flag}\n";
print "status               = $element->{status}\n";
print "pathname             = $element->{pathname}\n";

$dbh->disconnect();
