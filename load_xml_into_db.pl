#!/usr/local/bin/perl -w

# Some history: originally we had load_xml_into_db.pl which did cvs commits.
# Then it was converted to subversion. When git came along, we split into
# a svn script and a git script.  Now we need to distinguish between git and 
# svn commits. That is what load_xml_into_db.pl now does.
# 
# Now that I've realized the website should process both svn and git commits,
# I wanted a way to inspect an XML file and determine which type of repo it
# came from. This is vital because we have two different sets of code to deal
# with each origin:
# 
# [dan@devgit-ingress01:~/scripts] $ ls -l load_xml_into_db*
# -rwxr-xr-x  1 dan  dan  1251 Dec  5 03:00 load_xml_into_db.pl
# -rwxr-xr-x  1 dan  dan  1404 Jul  3 20:40 load_xml_into_db_git.pl
# -rwxr-xr-x  1 dan  dan  1404 Jul  3 20:40 load_xml_into_db_svn.pl
# 
# Invoke load_xml_into_db.pl and it determine the type of XML and then invoke
# one of load_xml_into_db_git.pl and load_xml_into_db_svn.pl
# 
# In turn, each of those scripts will use one of these modules:
# 
# [dan@devgit-ingress01:~/scripts] $ ls -l ~/modules/xml_munge*
# -rwxr-xr-x  1 dan  dan   5392 Dec  5 02:51 /usr/home/dan/modules/xml_munge.pm
# -rwxr-xr-x  1 dan  dan  36848 Dec  5 02:24 /usr/home/dan/modules/xml_munge_git.pm
# -rwxr-xr-x  1 dan  dan  31944 Dec  5 02:37 /usr/home/dan/modules/xml_munge_svn.pm
# 
# xml_munge.pm determines the type of repository this commit came from. This
# is important because there are slightly different data in the XML. For
# example, subversion does not have a commit_hash.
# 
# load_xml_into_db.pl learns the type from this data in the XML file:
# 
# <UPDATES Version="1.4.0.1" Source="git">
# <UPDATES Source="subversion" Version="1.3.2.2">
# 
# The Version numbers refer to the code module and is used. Yet.

#
# $Id: load_xml_into_db.pl,v 1.49 2006-12-17 12:04:01 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#
# Parse cvs messages in XML format so they can be put into a database
# Version 4 - uses DTD version 0.12
#
#
# return values - this may be out of date, looin into the Munge module for better information
#
#  1 - incorrect calling of script.  check your parameters
#  2 - this message id is already in the database
#  3 - No SystemID found for OS  - this OS     isn't being followed by FreshPorts
#  4 - No SystemBranchID found   - this branch isn't being followed by FreshPorts
#  5 - invalid file action found - the file action found wasn't recognized. Check the DTD.
#  6 - element id was not found  - possible problem adding new element to database.
#  7 - this messages does not deal with the ports subsystem.
#  8 - unknown source (e.g. not git or subversion)
#

# we make a great deal of use of a global variable Updates.  We should fix that up.
#

use strict;

use FreshPorts::database;
use FreshPorts::observer_commits;
use FreshPorts::xml_munge;

my $Munger = FreshPorts::XML_Munge->new();

print "about to process\n";
my $ErrorFound = $Munger->process();

my $source = $Munger->getSource();

print "That commit is of Type: '$source'\n";

print "EOF\n";

my $dbh = FreshPorts::Database::GetDBHandle();
if ($dbh->{Active}) {

	if ($source eq 'subversion') {

		print "invoking XML_Munge_svn because this is a subversion commit\n";
		use FreshPorts::xml_munge_svn;
		$Munger = FreshPorts::XML_Munge_svn->new($dbh);

	} elsif ($source eq 'git') {

		print "invoking XML_Munge_git because this is a git commit\n";
		use FreshPorts::xml_munge_git;
		$Munger = FreshPorts::XML_Munge_git->new($dbh);

	} else {
	    $dbh->disconnect();
	    die("Unkmown source: '$source'\n");
	}

	my $ObserverCommits = FreshPorts::ObserverCommits->new($dbh);

	$Munger->add_observer($ObserverCommits);

	print "about to process\n";
	$ErrorFound = $Munger->process();

	print " now is the commit:\n";

	$Munger->notify_observers($FreshPorts::Messages::TransactionCommitted);

	$dbh->disconnect();
	print "EOF\n";
}
