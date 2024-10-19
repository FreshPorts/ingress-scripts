#!/usr/local/bin/perl -w
#
# $Id: process_updating.pl,v 1.3 2008-02-01 14:31:31 dan Exp $
#
# Copyright (c) 2004-2006 DVL Software
#
# Original code by Travis Campbell (HCoyote).
#
# Parse /usr/ports/UPDATING and load into ports_updating table
#
# pipe the UPDATING file into this script.  Output is for diagnostics only 
# and can be dev/null'd.
#

use strict;
use warnings;

require Sys::Syslog;

use FreshPorts::branches;
use FreshPorts::db_utils;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::config;

use DBI;

FreshPorts::Utilities::InitSyslog();

print "I will be using this directory for ports: ";
print "$FreshPorts::Config::JailBaseDir$FreshPorts::Config::PortsDir\n";

&main;

exit;

sub usage {
	print "USAGE : $0 INPUTFILE\n";
}



#####
# Main Processing Routine
##### 
sub main {

	my $dbh;

	print "dbname = $FreshPorts::Config::dbname\n";

	$dbh = FreshPorts::Database::GetDBHandle();
	if ($dbh->{Active}) {

		my $currentBranch  = $FreshPorts::Constants::HEAD;

		# start off on head
		FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

		EmptyUpdating($dbh);

		parsefile($dbh);

		ClearCacheFiles($dbh);

# hmmm, this might be a good way to debug...
# issue a rollback after each attempt...
#
#		$dbh->rollback();
		$dbh->commit();

		$dbh->disconnect();
	}
}

sub parsefile ($) {
	my $dbh = shift;

	my $version;

	# slurp in UPDATING.
	my @lines = <STDIN>;
	chomp @lines;

	# start going through the file;
	for (my $i = 0; $i < scalar @lines; $i++) {
		# encounter a line with a date
		if ($lines[$i] =~ m/^(\d{8}):/) {
			my ($affects, $author, $msg, $InAffects);
			my $date = $1;

			$InAffects = 0;
			$affects   = '';
			# parse the stuff between lines with dates
			for (my $j = $i + 1; $j < scalar @lines; $j++) {
				my $line = $lines[$j];
				last if ($line =~ m/^\d{8}:/);
				last if ($line =~ m/^\$FreeBSD:/);	# last line of file, at one time.

				# Sometime after 20220629, entries started using 'AFFECTS: users of'.
				# The code still works with that format,
				# On 2024-09-06, the \s* replaced \s+ because of https://cgit.freebsd.org/ports/commit/?id=c27d2322b009732adbdc4211c38e1ff66dedf987
				# AUTHORS was also updated similarly.
				#
				if ($line =~ m/\s*AFFECTS:\s*(.*)$/i){
					$affects   = $1;
					$InAffects = 1;
					print "found this: 'AFFECTS: $affects'\n";
				} elsif ($line =~ m/\s*AUTHOR:\s*(.*)$/i) {
					$author    = $1;
					$InAffects = 0;
				} elsif ($InAffects) {
					# the AFFECTS section is usually terminated by the AUTHOR section.
					# sometimes there is no AUTHOR, and we have a blank line instead
					if ($line =~ m/\S+/) { # if the line contains something not-whitespace
						# grab the non-whitespace
						$line =~ m/^\s*(.*)$/;
						# line it up under the AFFECTS: banner
						$affects .= "\n         " . $1;
					} else {
						$InAffects = 0;
					}
				} else {
					$msg .= $line . "\n";
				}
			}

			print 'We have this for $affects: ' . $affects . "\n";
			# lets deal with port names
			my @ports;
			my @affects_match = split(/,?\s+/, $affects);

			# take the split up $affects tokens and see if they look
			# like ports entries.
			print "starting PARTS for '$affects'\n";
			for my $part (@affects_match) {
				print "This is the PART we are looking for '$part'\n";
				if ($part =~ m^/^) {
					$part =~ s/[()]//g;  # strip out unmentionables
					print "port found: '$part'\n";
					if ($part =~ m%[\*\{\}\[\],]%) {
						# suggested by mat@ for parsing
						# affect ports that look like shell
						# globs
						# go into this directory to get the glob function to work
						chdir "$FreshPorts::Config::JailBaseDir/$FreshPorts::Config::PortsDir";
						push @ports, glob $part;
					} else {
						push @ports, $part;
					}
				}
			}
			print "ending PARTS\n";

			my $ID = AddUpdating($dbh, $date, $affects, $author, $msg);

			print "Date    : $date\n";
			print "Affects : $affects\n";
			for my $port (@ports) {
				print "$date THE PORTS ARE: $port ($ID)\n";
				AddUpdatingXref($dbh, $ID, $port);
			}
			if ($author) {
				print "Author  : $author\n";
			} else { 
				print "Author  : unknown\n";
			}
			print "Message : $msg\n";
			print "-"x72, "\n";


		} elsif ($lines[$i] =~ m%^(\$FreeBSD: .+ \$)$%){
			# get the UPDATING version in case we want it later.
			$version = $1;
		}
	}
}

sub AddUpdating($;$;$;$;$) {
	my $dbh     = shift;
	my $Date    = FreshPorts::Utilities::NULLIfEmpty($dbh, shift);
	my $Affects = FreshPorts::Utilities::NULLIfEmpty($dbh, shift);
	my $Author  = FreshPorts::Utilities::NULLIfEmpty($dbh, shift);
	my $Reason  = FreshPorts::Utilities::NULLIfEmpty($dbh, shift);

	my $sth;
	my $sql;
	my @row;

	# quote everything going to the database
	$sql = "select PortsUpdatingAdd($Date\:\:date, $Affects, $Author, $Reason)";
	$sth = $dbh->prepare($sql);
	if (!$sth->execute())  {
		FreshPorts::Utilities::ReportError('warning', "Could not execute sql: '$sql'", 1);
	}
	@row = $sth->fetchrow_array();   
	$sth->finish();

	return $row[0];
}

sub AddUpdatingXref($;$;$) {
	my $dbh             = shift;
	my $PortsUpdatingID = $dbh->quote(shift);
	my $Port            = $dbh->quote(shift);

	my $sth;
	my $sql;
	my @row;

	# xxx debug
	my $currentBranch  = $FreshPorts::Constants::HEAD;
	FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

	# quote everything going to the database
	$sql = "select PortsUpdatingPortsXrefAdd($PortsUpdatingID, $Port)";
	print "$sql\n";
	$sth = $dbh->prepare($sql);
	if (!$sth->execute())  {
		FreshPorts::Utilities::ReportError('warning', "Could not execute sql: '$sql'", 1);
	}
	@row = $sth->fetchrow_array();   
	$sth->finish();

	return $row[0];
}

sub EmptyUpdating($) {
	my $dbh = shift;

	my $sth;
	my $sql;

	# quote everything going to the database
	$sql = "DELETE FROM ports_updating";
	$sth = $dbh->prepare($sql);
	if (!$sth->execute()) {
		FreshPorts::Utilities::ReportError('warning', "Could not execute sql: $sql", 1);
	}
}

sub ClearCacheFiles($) {
	my $dbh = shift;
	my $sth;
	my $sql;
	my $updated_port;
	my $i = 0;

	$sql = '
INSERT INTO cache_clearing_ports(port_id, category, port)
SELECT P.id,
       C.name AS category,
       E.name AS port
 FROM element E, categories C, ports P 
    JOIN (SELECT DISTINCT port_id
            FROM ports_updating_ports_xref) as tmp on P.id = tmp.port_id
           WHERE E.id = P.element_id
             AND C.id = P.category_id';

	print "sql is $sql\n";

	$sth = $dbh->prepare($sql);
	$sth->execute ||
		die "Could not execute SQL $sql ... maybe invalid?";

	# after populating the cache_clearing_ports table, we notify.
	$sth = $dbh->prepare("notify port_updated");
	$sth->execute ||
		die "Could not execute SQL $sql ... maybe invalid?";

}
