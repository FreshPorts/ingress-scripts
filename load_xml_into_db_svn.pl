#!/usr/local/bin/perl -w
#
# $Id: load_xml_into_db.pl,v 1.49 2006-12-17 12:04:01 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#
# Parse cvs messages in XML format so they can be put into a database
# Version 4 - uses DTD version 0.12
#
#
# return values
#  1 - incorrect calling of script.  check your parameters
#  2 - this message id is already in the database
#  3 - No SystemID found for OS  - this OS     isn't being followed by FreshPorts
#  4 - No SystemBranchID found   - this branch isn't being followed by FreshPorts
#  5 - invalid file action found - the file action found wasn't recognized. Check the DTD.
#  6 - element id was not found  - possible problem adding new element to database.
#  7 - this messages does not deal with the ports subsystem.
#

# we make a great deal of use of a global variable Updates.  We should fix that up.
#

use strict;

use FreshPorts::database;
use FreshPorts::xml_munge_svn;
use FreshPorts::observer_commits;

my $dbh = FreshPorts::Database::GetDBHandle();
if ($dbh->{Active}) {

	my $ObserverCommits = FreshPorts::ObserverCommits->new($dbh);

	my $Munger = FreshPorts::XML_Munge->new($dbh);

	$Munger->add_observer($ObserverCommits);

	print "about to process\n";
	my $ErrorFound = $Munger->process();

	print " now is the commit:\n";

	$Munger->notify_observers($FreshPorts::Messages::TransactionCommitted);

	$dbh->disconnect();
	print "EOF\n";
}
