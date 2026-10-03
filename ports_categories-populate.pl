#!/usr/local/bin/perl -w
#
# $Id: ports_categories-populate.pl,v 1.2 2006-12-17 12:04:01 dan Exp $
#
# Copyright (c) 1999-2026 Dan Langille
#

use strict;
use FreshPorts::port;
use DBI;
use FreshPorts::category;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::ports_categories;

my $dbh;

my @PORTS;
my $port;
my $sql;
my $sth;
my $row;
my %Categories;
my %port;
my $category;
my $ACategory;
my $ports_categories;

$dbh = FreshPorts::Database::GetDBHandle();

$category = FreshPorts::Category->new($dbh);
%Categories = $category->FetchAll();


#
# get our existing list of categories
#

$sql = "select * from categories order by name";
print "sql = '$sql'\n";

$sth = $dbh->prepare($sql);
if ( !defined $sth ) {
   FreshPorts::Utilities::ReportError('warning', "Could not prepare SQL $sql" . pg_last_error(), 1);
}
if (!$sth->execute) {
   FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql" . pg_last_error(), 1);
}

while ($row = $sth->fetchrow_hashref()) {
   print "found $row->{id} = $row->{name}\n";
   $Categories{$row->{name}} = $row->{id};
}

$sth->finish();

#
# get a list of ports to update
#

$sql = "
  SELECT ports_active.id         AS id, 
         ports_active.categories AS categories,
         ports_active.name       AS name,
         ports_active.category   AS category
    FROM ports_active
ORDER BY ports_active.id";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while ($row=$sth->fetchrow_hashref) {
#	print "now processing $row->{id}/$row->{categories}\n";
	$port{id}           = $row->{id};
	$port{categories}   = $row->{categories};
	$port{category}     = $row->{category};
	$port{name}         = $row->{name};

	#
	# by enclosing the has in { }
	# we are creating an anonymous hash
	#
	push @PORTS, {%port};
}

$ports_categories = FreshPorts::PortsCategories->new($dbh);
 
foreach $port (@PORTS) {
	my $port_id    = $port->{id};
	my $categories = $port->{categories};
	my %PortCategories;	# list of categories for this port, used to find duplicates

	# for each category in categories
	my @TheCategories = split(/ /, $categories);
	foreach $ACategory (@TheCategories) {
		# look for duplicate categories for this port
		if (defined($PortCategories{$ACategory})) {
			print "port $port->{category}/$port->{name} : $ACategory => $categories\n";
			next;
		} else {
			$PortCategories{$ACategory} = 1;
		}

		# if not found in %Categories
#		print "looking for $ACategory... ";
		if (!defined($Categories{$ACategory})) {
			# add a virtual entry to categories table with is_primary = false
#			print "we need to add this virtual category : '$ACategory'\n";

			$category = FreshPorts::Category->new($dbh);

			$category->{name}        = $ACategory;
			$category->{is_primary}  = 0;
			$category->{description} = 'no description supplied';
			$category->save();

			$Categories{$ACategory} = $category->{id};

#			print "adding this to Categories: '$ACategory' => '$category->{id}'\n";
		}
		# add port_id, category_id to ports_categories table
		$ports_categories->{port_id}     = $port_id;
		$ports_categories->{category_id} = $Categories{$ACategory};

		$ports_categories->save();
	}
}

$dbh->commit();
$sth->finish();
$dbh->disconnect();
