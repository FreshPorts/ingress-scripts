#!/usr/local/bin/perl -w
#
# Copyright (c) 1999-2026 DVL Software
#

# Refresh each port named in a file, one category/port per line.
#
# Written for the output of compare-index.sh, which finds ports whose version
# in the database no longer matches the ports tree.
#
#   refresh-listed-ports.pl /var/db/freshports/cache/spooling/refresh.txt
#   compare-index.sh ... | refresh-listed-ports.pl -
#
# HEAD only, as process_default_versions.pl is.
#

use strict;
use FreshPorts::branches;
use FreshPorts::port;
use DBI;
use FreshPorts::config;
use FreshPorts::constants;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::system_status;
use Getopt::Long;

my $dbh;
my $sql;
my $sth;

my $dryrun = 'n';
my $debug  = 'n';

if (!GetOptions('debug=s' => \$debug, 'dryrun=s' => \$dryrun)) {
	exit;
}

if ($dryrun ne 'y' && $dryrun ne 'n') {
	print("--dryrun must be y or n\n");
	exit;
}

my $filename = shift;

if (!defined($filename)) {
	print("usage: $0 [--debug y] [--dryrun y] FILE\n");
	print("       FILE holds one category/port per line, or - for stdin\n");
	exit 1;
}

my $LIST;
if ($filename eq '-') {
	$LIST = \*STDIN;
} else {
	open($LIST, '<', $filename) || die "$0: cannot read $filename: $!\n";
}

FreshPorts::Utilities::InitSyslog();

print("$0 starts\n");

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

$dbh = FreshPorts::Database::GetDBHandle();

my $currentBranch = $FreshPorts::Constants::HEAD;
# start off on head
FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

$sql = "SET CLIENT_ENCODING TO 'ISO-8859-1';
        select P.id as port_id
          from element_pathname EP, ports P
         where pathname = ?
           and EP.element_id = P.element_id";

if ($debug eq 'y') {
	print "\$dryrun='$dryrun'\n";
	print "sql = $sql\n";
}

$sth = $dbh->prepare($sql);

my $refreshed = 0;
my $failed    = 0;
my $notfound  = 0;

while (my $category_port = <$LIST>) {
	chomp($category_port);

	# ignore blank lines, and comments, so a list can be annotated
	$category_port =~ s/#.*//;
	$category_port =~ s/^\s+|\s+$//g;
	next if ($category_port eq '');

	if ($category_port !~ m|^[^/]+/[^/]+$|) {
		FreshPorts::Utilities::ReportError('warning', "not a category/port: '$category_port'", 0);
		$failed++;
		next;
	}

	# Ports_HEAD_commit contains a trailing slash
	my $element_pathname = $FreshPorts::Constants::Ports_HEAD_commit . $category_port;

	print("$0 working on '$category_port' ('$element_pathname')\n");

	if ($dryrun eq 'y') {
		next;
	}

	$sth->execute($element_pathname) ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid? with '$element_pathname'", 1);

	my $row     = $sth->fetchrow_hashref();
	my $port_id = $row->{port_id};

	if (!defined($port_id)) {
		FreshPorts::Utilities::ReportError('warning', "No such port on $currentBranch: '$category_port'", 0);
		$notfound++;
		next;
	}

	print "now processing $category_port with port_id = $port_id\n";

	# We shall assume 'git' because the code needs a value.
	#
	my $port = FreshPorts::Port->new($dbh, 'git');

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
		my $result = $port->RefreshFromFiles($currentBranch, $currentBranch);

		if ($result == 0) {
			$port->save($currentBranch);
			# commit each port on its own, so a failure part way through
			# does not throw away the ports already done
			$dbh->commit();
			$refreshed++;
		} else {
			$dbh->rollback();
			FreshPorts::Utilities::ReportError('warning', "Could not refresh '$category_port' (result $result)", 0);
			$failed++;
		}
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not Fetch port ($category_port)", 0);
		$failed++;
	}
}

close($LIST) if ($filename ne '-');

$sth->finish();

print "$0 ends: $refreshed refreshed, $failed failed, $notfound not found\n";

$dbh->commit();
$dbh->disconnect();
