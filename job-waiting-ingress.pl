#!/usr/local/bin/perl -w
#
# $Id: job-waiting.pl,v 1.3 2007-01-29 00:17:35 dan Exp $
#
# Copyright (c) 1999-2007 DVL Software
#
# This script is invoked by the fp-ingress.sh script
# usually located in /var/services/freshports
#

use strict;

use DBI;
use FreshPorts::database;
use FreshPorts::cache;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::system_status;
use FreshPorts::utilities;

my $dbh;

my %Jobs = (
	$FreshPorts::Config::CheckGit                 => 'check_git.sh',
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
