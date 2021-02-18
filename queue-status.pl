#!/usr/local/bin/perl -w
#
# $Id: queue-status.pl,v 1.3 2012/10/17 18:10:22 dan Exp $
#
# Copyright (c) 2001-2006 DVL Software
#

use strict;

use FreshPorts::config;
use FreshPorts::database;
use FreshPorts::utilities;

my $Debug = 0;

sub SendNotice($) {
	my $Msg		= shift;
	my $hostname	= `hostname`;

	chomp $hostname;

	my $Body = 'At ' . $hostname . ' ' . $Msg . "\n";
	print $Body;
}

#
# this is a hash, one entry for each queue.
# For each queue, we have a directory name on disk, and the the pattern of the file we search for.
# This pattern is usually a simple suffix, used as a glob with ls.
#
my %queues = (
	ingress_incoming => {
		'/var/db/ingress/message-queues/incoming'  => '*.txt'
		}, 
	ingress_svn_incoming => {
		'/var/db/ingress_svn/message-queues/incoming'  => '*.txt'
		}, 
	ingress_svn_spooling => {
		'/var/db/ingress_svn/message-queues/spooling'  => ''
		}, 
	freshports_retry => {
		'/var/db/freshports/message-queues/retry'  => '*.txt'
		}, 
	freshports_recent => {
		'/var/db/freshports/message-queues/recent' => '*.xml'
		},
);


my %report_non_zero = ('ingress_incoming' => 1, 'ingress_svn_incoming' => 1, 'ingress_svn_spooling' => 1, 'freshports_retry' => 1);

my $Interval = '10 minutes';

my $send_report = 0;
my $msg         = '';

my $CountRecent;

undef($CountRecent);

my $dbh = FreshPorts::Database::GetDBHandle();

$msg .= "SITE: $FreshPorts::Config::FreshPortsURL ";
for my $queue ( keys %queues ) {
	if ($Debug) {print $queue ."\n";}
	for my $directory ( keys %{ $queues{$queue} } ) {
		if ($Debug) { print " * $directory \n"; }
    
		my $pattern = $queues{$queue}{$directory};
		if ($Debug) { print "   * $pattern\n"; }
		my $Command = "find $directory/";
		if ($Debug) { print $Command . "\n"; }

		if ($pattern ne '') {
			$Command .= " -name \"$pattern\"";
		}
		$Command .= ' -maxdepth 1 -mmin +5 | wc -l';

		if ($Debug) { print $Command . "\n"; }

		my $Count = `$Command`;
		chomp $Count;
		$Count = FreshPorts::Utilities::trim($Count);
		$msg .= " $queue: $Count ";

		if (($queue eq 'ingress_incoming' || $queue eq 'ingress_svn_incoming') && $Count && defined($report_non_zero{$queue})) {
			if (!defined($CountRecent)) {
				$CountRecent = FreshPorts::Utilities::CommitCountPeriod($dbh, $Interval);
			}
			if ($Count > $CountRecent) {
				$send_report = 1;
			}
		}
	}
}

$msg .= " ";

if ($send_report) {
#	Sys::Syslog::syslog('notice', 'There is a problem with the FreshPorts queues');
	SendNotice($msg);
	$dbh->disconnect();
	exit(1)
} else {
	print 'Queues are OK. ';
	print $msg;
	$dbh->disconnect();
}
