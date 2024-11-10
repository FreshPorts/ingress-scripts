#!/usr/local/bin/perl -w
#
# $Id: job-waiting.pl,v 1.3 2007-01-29 00:17:35 dan Exp $
#
# Copyright (c) 1999-2021 DVL Software
#
# This script is invoked by the helper_scripts/check_for_git_commits.sh script
# usually located in /usr/local/libexec/freshports.
# Look in /usr/local/etc/periodic/everythreeminutes/215.fp_check_git_for_commits for more information
#

use strict;

use DBI;
use FreshPorts::database;
use FreshPorts::cache;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::system_status;
use FreshPorts::utilities;

# added in for testing
require Sys::Syslog;

FreshPorts::Utilities::InitSyslog();

#die('we are done here - stopped');

Sys::Syslog::syslog('warning', "running job-waiting.pl");

my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	Sys::Syslog::syslog('warning', "$0 stopping now: system is offline");
	exit 0;
}



my %Jobs_ingress = (
	$FreshPorts::Config::CheckGit                 => 'check_git.sh',
	);

my %Jobs_freshports = (
	$FreshPorts::Config::MovedFileFlag            => 'process_moved.sh',
	$FreshPorts::Config::NewReposReadyForImport   => 'import_packagesite.py',
	$FreshPorts::Config::UpdatingFileFlag         => 'process_updating.sh',
	$FreshPorts::Config::PortsToRefresh           => 'refresh-ports.sh',
	$FreshPorts::Config::VuXMLFileFlag            => 'process_vuxml.sh',
	$FreshPorts::Config::DefaultVersionsFlag      => 'process_default_versions.pl',
	$FreshPorts::Config::CheckPortsCategoriesFlag => 'missing-port-categories.sh',
	);

FreshPorts::Utilities::Report('notice', "starting $0");

#	
# This script is invoked by either the freshports or the ingress user
# they have separate lists of jobs to look for. Rather than maintain two
# scripts, there is one.
#
my $username = getpwuid($<);
my %Jobs;

FreshPorts::Utilities::Report('notice', "running $0 as user = '$username'");

if ($username eq 'freshports') {
   %Jobs = %Jobs_freshports;
} elsif ($username eq 'ingress') {
   %Jobs = %Jobs_ingress;
} else {
  FreshPorts::Utilities::Report('notice', "WHO IS THAT USER? I don't know them. Stopping.");
  die($0 . ' must be run only as the ingress or freshports users');
  exit;
}

	
FreshPorts::Utilities::Report('notice', "checking jobs for $username");

#
# we should put a max loop in here. Loop 100 times, then stop
#
my $JobFound;
my $NumLoops = 0;


do {
	$JobFound = 0;
	# one job might create another, so we keeping looping until they are all cleared.
	while (my ($flag, $script) = each %Jobs) {
		if (-f $flag) {
			$JobFound =1;
			FreshPorts::Utilities::Report('notice', "$flag exists.  About to run $script via system()");
			# this must be >> so that each run is appended to the log, which is rotated at midnight
			FreshPorts::Utilities::Report('notice', "details are: $FreshPorts::Config::ScriptDir/$script >> $FreshPorts::Config::LogJobsWaiting");
			system("$FreshPorts::Config::ScriptDir/$script >> $FreshPorts::Config::LogJobsWaiting");
			if ($? == 0) {
				# all ok
				FreshPorts::Utilities::ReportError('notice', "$script finished with exit status '$?' and '$!'");
			} else {
				FreshPorts::Utilities::ReportError('notice', "$script failed with exit status '$?' and '$!'");
			}
			FreshPorts::Utilities::Report('notice', "Finished running $script");
		} else {
			FreshPorts::Utilities::Report('notice', "flag '$flag' not set.  no work for $script");
		}
	}

	$NumLoops++;

	# If we're going throught there more than N times, a script has forgotten to remove a flag
	# or is erroring out.

} until (!$JobFound || $NumLoops > 5);

if ($JobFound) {
	FreshPorts::Utilities::Report('err', "job-waiting.pl seems to be looping. Whatever flag is not being removed, that script may be silenting failing. Best check the logs.");
}
