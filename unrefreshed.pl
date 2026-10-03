#!/usr/local/bin/perl -w
#
# $Id: unrefreshed.pl,v 1.12 2006-12-17 12:04:03 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#

use strict;

use FreshPorts::port;
use FreshPorts::database; 
use DBI;
use FreshPorts::email;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::system_status;

require FreshPorts::config;


sub SendNotice($;$;$) {
	my $To	 	= shift;
	my $count	= shift;
	my $list	= shift;
	my $hostname	= `hostname`;

	chomp $hostname;

	my $From         = 'FreshPorts Daemon <FreshPorts@FreshPorts.org>';
	my $CC           = '';
	my $Subject      = 'FreshPorts -- ports needing refresh';
	my %ExtraHeaders = (
		'Auto-Submitted'             => 'auto-generated',
		'Precedence'                 => 'bulk',
		'X-FreshPorts-RefreshNeeded' => $count,
	);


	my $Body = 'At ' . $hostname . '::' . $FreshPorts::Config::dbname . ", there are $count ports needing refresh.

$list
";

	FreshPorts::email::SendMail($From, $To, $CC, $Subject, $Body, \%ExtraHeaders);
}


sub usage {
	print "USAGE : $0 INPUTFILE [-d] [-i]\n";
	print "   -i : include any ignored commits\n";
	print "   -d : include debugging information\n";
}

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

my $ExcludeIgnoredCommits = 1;
my $Debug                 = 0;

if (($#ARGV+1) >= 1) {
	for (my $i = 0; $i < ($#ARGV+1); $i++) {
		if ($Debug) {
			print "checking arg $i\n";
		}

		if ($ARGV[$i] eq '-i') {
			print "including Ignored commits....\n";
			$ExcludeIgnoredCommits = 0;
			next;
		}

		if ($ARGV[$i] eq '-d') {
			print "including debugging....\n";
			$Debug = 0;
			next;
		}

		# we have found arguments we know nothing about
		print 'unknown argument ' . $ARGV[$i] . "\n";
		usage();
		exit 1;
	}
}

my $dbh = FreshPorts::Database::GetDBHandle();

my $sql;
my $sth;
my $row;

#
# get a list of unrefreshed ports which have been in the db more than 10 minutes
#

$sql = "
select ports.id         as port_id, 
       element.name     as port, 
       categories.name  as category,
       commit_log_ports.commit_log_id
  from ports, categories, element, commit_log, commit_log_ports 
 where ports.category_id               = categories.id
   and ports.element_id                = element.id
   and commit_log_ports.port_id        = ports.id
   and commit_log_ports.needs_refresh <> 0
   and element.status                  = 'A'
   and commit_log_ports.commit_log_id  = commit_log.id
   and commit_log.date_added           < now() - interval '10 minutes'
";

if ($ExcludeIgnoredCommits) {
	$sql .= "   and not exists (select *
                     FROM commit_log_ports_ignore
                    WHERE commit_log_ports_ignore.commit_log_id = commit_log_ports.commit_log_id)";
}

$sql .= "
order by category, port";

if ($Debug) {
	print $sql;
}

$sth = $dbh->prepare($sql);
$sth->execute ||
        die "Could not execute SQL $sql ... maybe invalid?";

my @commits;
my $rowcount = 0;
my $list     = '';
my %commit;
while ($row=$sth->fetchrow_hashref()) {
	$rowcount++;
	$list .= "id=$row->{port_id} $row->{category}/$row->{port} $row->{commit_log_id}\n";
	
	$commit{port_id}       = $row->{port_id};
	$commit{commit_log_id} = $row->{commit_log_id};
	push @commits, {%commit};
	
}

if ($rowcount > 0) {
	my $hostname = `hostname`;
	chomp $hostname;
	print "at $hostname, $rowcount port[s] need[s] refresh\n";
	print $list;

	print "$ENV{HOME} is where we were\n";
	SendNotice($FreshPorts::Config::SystemOwnerEmail, $rowcount, $list);
}

$sth->finish();

if ($ExcludeIgnoredCommits) {
	my $MyCommit;
	my $PortsIgnoreRefresh = FreshPorts::PortsIgnoreRefresh->new($dbh);

	foreach $MyCommit (@commits) {
		print "commit_log_id='$MyCommit->{commit_log_id}' port_id='$MyCommit->{port_id}'\n";
	
		# for each port notified, add an entry to the ignore table.
		# these are cleared out at the end of each day if the port has been refreshed, otherwise
		# the admin is notified

		$PortsIgnoreRefresh->{commit_log_id} = $MyCommit->{commit_log_id};
		$PortsIgnoreRefresh->{port_id}       = $MyCommit->{port_id};
		$PortsIgnoreRefresh->{reason}        = 'auto-ignored';
	
		$PortsIgnoreRefresh->save();
	}
}

$dbh->commit();

$dbh->disconnect();
