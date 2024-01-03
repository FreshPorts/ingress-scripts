#!/usr/local/bin/perl -w
#
# $Id: refresh-unrefreshed-ports.pl,v 1.25 2012-09-04 00:06:23 dan Exp $
#
# Copyright (c) 1999-2004 DVL Software
#

use strict;

use FreshPorts::port;
use DBI;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::commit_log_ports;
use FreshPorts::system_status;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::caching;
use Getopt::Long;

my $dbh;

my $porttorefresh;
my @PORTS;
my %Port;
my $sql;
my $sth;
my @row;

# items set on command line
my $fetch_before_refresh = 1;
my $message_id           = '';
my $port_name            = '';

my $currentBranch  = $FreshPorts::Constants::HEAD;

FreshPorts::Utilities::InitSyslog();

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	Sys::Syslog::syslog('warning', "not looking for refresh status: system is offline");
	exit 0;
}

GetOptions ('fetch:i' => \$fetch_before_refresh, 'message_id:s' => \$message_id, 'port:s' => \$port_name);

print "fetch='$fetch_before_refresh'\n";
print "message_id='$message_id'\n";
print "port_name='$port_name'\n";

if ($message_id && $port_name) {
  print "ERROR: --message_id and --port are mutually exclusive\n";
  exit;
}

if (!$message_id && !$port_name) {
  print "ERROR: at least one of --message_id and --port must be supplied\n";
  exit;
}

$dbh = FreshPorts::Database::GetDBHandle();

# start off on head
FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

#
# get a list of ports to update
#

$sql = "select ports.id, categories.name as category, element.name as port, commit_log_ports.needs_refresh, 
			   commit_log_ports.commit_log_id, to_char(commit_log.commit_date - SystemTimeAdjust(), 'YYYY-MM-DD') as commit_date,
			   coalesce(commit_log.svn_revision, '') as svn_revision
        from ports, categories, element, commit_log_ports, commit_log
        where ports.category_id              = categories.id 
          and ports.element_id               = element.id
		  and commit_log_ports.port_id       = ports.id  
          and commit_log_ports.needs_refresh <> 0 
		  and element.status				 = 'A'
		  and commit_log.id                  = commit_log_ports.commit_log_id";

if ($message_id) {
  $sql .= ' and commit_log.message_id = ' . $dbh->quote($message_id);
} elsif ($port_name) {
  $sql .= ' and element.id = GetPort(' . $dbh->quote($port_name) . ')';
}

$sql .= " ORDER BY category, port LIMIT 1";

print "sql = $sql\n";

$sth = $dbh->prepare($sql);
$sth->execute ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid?", 1);

while (@row=$sth->fetchrow_array) {
	print "now processing @row\n";
	$Port{id}            = $row[0];
	$Port{category}      = $row[1];
	$Port{port}          = $row[2];
	$Port{needs_refresh} = $row[3];
	$Port{commit_log_id} = $row[4];
	$Port{commit_date}   = $row[5];
	$Port{svn_revision}  = $row[6];

	#
	# by enclosing the has in { }
	# we are creating an anonymous hash
	#
	push @PORTS, {%Port};
}
 
my $port				= FreshPorts::Port->new($dbh);
my $element				= FreshPorts::Element->new($dbh);
my $commit_log_ports	= FreshPorts::CommitLogPorts->new($dbh);

my $Caching				= FreshPorts::Caching->new($dbh);


my %DatesToRefresh;

foreach $porttorefresh (@PORTS) {
	my $result;

	my $port_id       = $porttorefresh->{id};
	my $category_name = $porttorefresh->{category};
	my $port_name     = $porttorefresh->{port};
	my $needs_refresh = $porttorefresh->{needs_refresh};
	my $commit_log_id = $porttorefresh->{commit_log_id};
	my $commit_date   = $porttorefresh->{commit_date};
	my $svn_revision  = $porttorefresh->{svn_revision};

	print "found $category_name/$port_name $needs_refresh $commit_log_id $commit_date $svn_revision\n";

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
		$result = 0;
		$element->{id} = $port->{element_id};
		if (defined($element->FetchByID())) {
			if ($element->{status} eq $FreshPorts::Element::Deleted) {
				#
				# this port is deleted but needs refresh.
				#
				print "that port has been deleted and will not be refreshed\n";
				$result = 0;
			} else {
#				print "we need to add CommitBranch to this call\n";
#				exit;
				$result = $port->RefreshFromFiles($currentBranch, $needs_refresh, $fetch_before_refresh, $svn_revision);
				print "refresh attempt done ($result)\n";
			}
		} else {
			FreshPorts::Utilities::ReportError('warning', "Could not retrieve element ($port_id, $category_name, $port_name, $needs_refresh, $commit_log_id)", 1);
		}

		#
		# now reset refreshed
		#
		if ($result == 0) {

			$port->save($currentBranch);

			$commit_log_ports->{commit_log_id}	= $commit_log_id;
			$commit_log_ports->{port_id}		= $port->{id};
			$commit_log_ports->{needs_refresh}	= 0;
			$commit_log_ports->{port_version}	= $port->{version};
			$commit_log_ports->{port_revision}	= $port->{revision};
			$commit_log_ports->{saved}			= 1;	# this forces an update, instead of an insert

			$commit_log_ports->save();

			#
			# commit everything we've done.  we don't want it falling over during
			# the daily summary creation and then doing a rollback.
			#
			$dbh->commit();
			
			print "removing from cache: $port->{category}/$port->{name}\n";
			$Caching->RemovePortFromCache($commit_log_ports->{port_id}, $port->{category}, $port->{name});

			#
			# save that date away for later use
			#
			$DatesToRefresh{"$commit_date"} = "$commit_date";
		} else {
			print "update result is $result ******************************************\n";
			$dbh->rollback();
		}
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not retrieve port ($port_id, $category_name, $port_name, $needs_refresh, $commit_log_id)", 1);
	}
}

$sth->finish();

#
# now save all those commit values away
#
while ( my ($key, $value) = each %DatesToRefresh) {
	$sql = "select DailySummaryDateAdd('$key')";
	print "sql is $sql\n";

	$sth = $dbh->prepare($sql);
	if (!$sth->execute) {
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid? ". $dbh->errstr, 1);
	}
}

$sth->finish();

$dbh->commit();
$dbh->disconnect();
