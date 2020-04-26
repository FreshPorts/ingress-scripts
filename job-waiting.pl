#!/usr/local/bin/perl -w
#
# $Id: job-waiting.pl,v 1.3 2007-01-29 00:17:35 dan Exp $
#
# Copyright (c) 1999-2007 DVL Software
#

use strict;

use DBI;
use FreshPorts::database;
use FreshPorts::cache;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::system_status;
use FreshPorts::utilities;

my $dbh;

my $DaysRefreshed;

my %Jobs = (
	$FreshPorts::Config::MovedFileFlag            => 'process_moved.sh',
	$FreshPorts::Config::UpdatingFileFlag         => 'process_updating.sh',
	$FreshPorts::Config::VuXMLFileFlag            => 'process_vuxml.sh',
	$FreshPorts::Config::WWWENPortsCategoriesFlag => 'process_www_en_ports_categories.sh',
	$FreshPorts::Config::NewReposReadyForImport   => 'import_packagesite.py',
	$FreshPorts::Config::NewRepoImported          => 'UpdatePackagesFromRawPackages.py',
	);

my $JobFound;
do {
	$JobFound = 0;
	# one job might create another, so we keeping looping until they are all cleared.
	while (my ($flag, $script) = each %Jobs) {
		if (-f $flag) {
			$JobFound =1;
			FreshPorts::Utilities::Report('notice', "$flag exists.  About to run $script");
			`$FreshPorts::Config::scriptpath/$script`;
			FreshPorts::Utilities::Report('notice', "Finished running $script");
		} else {
			FreshPorts::Utilities::Report('notice', "flag '$flag' not set.  no work for $script");
		}
	}
} until (!$JobFound);
