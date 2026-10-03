#!/usr/local/bin/perl -w
#
# $Id: hourly_stats.pl,v 1.2 2006-12-17 12:04:00 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#

use strict;

use FreshPorts::port;
use FreshPorts::database; 
use DBI;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::system_status;

my %Queries = (
	new         => 'select Stats_PortCount()',
	broken      => 'select Stats_PortCountBroken()',
	deprecated  => 'select Stats_PortCountDeprecated()',
	ignore      => 'select Stats_PortCountIgnore()',
	forbidden   => 'select Stats_PortCountForbidden()',
	restricted  => 'select Stats_PortCountRestricted()',
	no_cdrom    => 'select Stats_PortCountNoCDROM()',
	vulnerable  => 'select Stats_PortCountVulnerable()',
	expiration  => 'select Stats_Expiration()',
	expired     => 'select Stats_Expired()',
	interactive => 'select Stats_Interactive()',
	today       => 'select Stats_PortCountNewToday()',
	yesterday   => 'select Stats_PortCountNewYesterday()',
	week        => 'select Stats_PortCountNewThisWeek()',
	fortnight   => 'select Stats_PortCountNewInterval(\'2 weeks\')',
	month       => 'select Stats_PortCountNewInterval(\'1 month\')',
);

my %Stats;

require FreshPorts::config;

sub GetStatistics($) {
	my $dbh = shift;

	my @row;

	while (my ($key, $query) = each %Queries) {
		print "processing $key => $query";
		my $sth = $dbh->prepare($query);

		$sth->execute ||
			FreshPorts::Utilities::ReportError('warning', "Could not execute SQL statement\n--$query--\n... maybe invalid?", 1);

		@row = $sth->fetchrow_array;
		$Stats{$key} = $row[0];

		print " ==  $Stats{$key}\n";
		$sth->finish();
	}
}


sub CreateHourlySummary() {

	my $myrow;

	umask(02);
	# create the output file name gradually, ensuring the directories exist

	my $OutputFileDir = $FreshPorts::Config::HourlySummaryDir;

	if (-d $OutputFileDir) {
		print "'$OutputFileDir' exists\n";
	} else {
		print "'$OutputFileDir' does not exist\n";
		print "   trying to mkdir '$OutputFileDir'\n";
		if (mkdir $OutputFileDir, 0775) {
		} else {
			print "Could not create directory $OutputFileDir\n";
			return 1;
		}
	}

	my $OutputFile = "$OutputFileDir/stats-temp.html";
	print "trying to open '$OutputFile'\n";
   
	if (open(FILE, ">$OutputFile")) {
		print "that file was opened.  now writing output\n";
		my $count =0;

		print FILE '<BR>Calculated hourly:<BR>';

		print FILE '<TABLE>' . "\n";
		print FILE '<TR><TD><A HREF="/categories.php" TITLE="Number of ports in the database">Port count</A></TD> <TD>'      . $Stats{new}       . '</TD></TR>' . "\n";

		print FILE '<TR><TD><A HREF="/ports-broken.php" TITLE="Broken ports">Broken</A></TD>     <TD>'    . $Stats{broken}    . '</TD></TR>' . "\n";
		print FILE '<TR><TD><A HREF="/ports-deprecated.php" TITLE="Ports that have been deprecated">Deprecated</A></TD>     <TD>'    . $Stats{deprecated}    . '</TD></TR>' . "\n";
		print FILE '<TR><TD><A HREF="/ports-ignore.php" TITLE="Ports that you should ignore">Ignore</A></TD>     <TD>'    . $Stats{ignore}    . '</TD></TR>' . "\n";

		print FILE '<TR><TD><A HREF="/ports-forbidden.php" TITLE="Ports that are forbidden">Forbidden</A></TD>  <TD>' . $Stats{forbidden} . '</TD></TR>' . "\n";
		print FILE '<TR><TD><A HREF="/ports-restricted.php" TITLE="Ports that are restricted">Restricted</A></TD>  <TD>' . $Stats{restricted} . '</TD></TR>' . "\n";
		print FILE '<TR><TD><A HREF="/ports-no-cdrom.php" TITLE="Ports that are marked as NO CDROM">No CDROM</A></TD>  <TD>' . $Stats{no_cdrom} . '</TD></TR>' . "\n";
		print FILE '<TR><TD><A HREF="/ports-vulnerable.php" TITLE="Ports that vulnerable to exploitation">Vulnerable</A></TD>  <TD>' . $Stats{vulnerable} . '</TD></TR>' . "\n";

		print FILE '<TR><TD><A HREF="/ports-expired.php" TITLE="Ports that have expired">Expired</A></TD>  <TD>' . $Stats{expired} . '</TD></TR>' . "\n";
		print FILE '<TR><TD><A HREF="/ports-expiration-date.php" TITLE="Ports that have an expiration date set">Set to expire</A></TD>  <TD>' . $Stats{expiration} . '</TD></TR>' . "\n";

		print FILE '<TR><TD><A HREF="/ports-interactive.php" TITLE="Ports that require interaction during installation">Interactive</A></TD>  <TD>' . $Stats{interactive} . '</TD></TR>' . "\n";
		print FILE '<TR><TD><A HREF="/ports-new.php?interval=today" TITLE="Ports added in the last 24 hours">new 24 hours</A></TD>    <TD>'     . $Stats{today}     . '</TD></TR>' . "\n";

		print FILE '<TR><TD><A HREF="/ports-new.php?interval=yesterday" TITLE="Ports added in the last 48 hours">new 48 hours</A></TD><TD>'     . $Stats{yesterday} . '</TD></TR>' . "\n";

		print FILE '<TR><TD><A HREF="/ports-new.php?interval=week" TITLE="Ports added in the last 7 days">new 7 days</A></TD><TD>'            . $Stats{week}      . '</TD></TR>' . "\n";
		print FILE '<TR><TD><A HREF="/ports-new.php?interval=fortnight" TITLE="Ports added in the last 14 days">new fortnight</A></TD><TD>'         . $Stats{fortnight} . '</TD></TR>' . "\n";
		print FILE '<TR><TD><A HREF="/ports-new.php?interval=month" TITLE="Ports added in the last month">new month</A></TD><TD>'             . $Stats{month}     . '</TD></TR>' . "\n";
		print FILE '</TABLE>' . "\n";

		print "closing file\n";
		close FILE;

		print "renaming '$OutputFile' to '$OutputFileDir/stats.html'\n";
		rename "$OutputFile", "$OutputFileDir/stats.html";
	} else {
		print "could not open '$OutputFile'\n";
		return 3;
	}
   
	return 0;
}


#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}


my $dbh = FreshPorts::Database::GetDBHandle($FreshPorts::Constants::DB_ConnectionType => $FreshPorts::Constants::DB_ConnectionType_ReadOnly);

GetStatistics($dbh);
CreateHourlySummary();

$dbh->disconnect();
