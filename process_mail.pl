#!/usr/local/bin/perl -w
#
# $Id: process_mail.pl,v 1.7 2012-07-12 19:26:10 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#
# Process determine if this is cvs or svn email, and invoke the correct code.
# and convert it to XML output according to the FreshPorts DTD.
#

use strict;
use FreshPorts::branches;
use XML::Writer;
use FreshPorts::constants;
use FreshPorts::utilities;
use FreshPorts::process_mail;

&main;
exit;

#####
# Main Processing Routine
#####
sub main {
	# Get the message
	my ($message) = FreshPorts::ProcessMail::myGetMessage;
	
	my $Message_Subject = FreshPorts::ProcessMail::myGetMessage_Subject($message);

	# the message id uniquely identifies the email, and thus, the commit in question
	# the message id should be in one of two forms (given that we are processing stuff from just two lists):
	#  201108100855.p7A8tkQt033487@svn.freebsd.org     (SVN commit)
	#  201108101456.p7AEuU2o048428@repoman.freebsd.org (CVS commit)
	
	my $MessageId = FreshPorts::ProcessMail::myGetMessage_Id($message);
	if (!defined($MessageId)) {
		FreshPorts::Utilities::ReportErrorEmailNoPrint('err', "No Message-Id found for this commit message (" . $Message_Subject . ").\n\nIs this a corrupted commit or email?", 1)
	}

	# the List Id helps to tell us which script is needed for processing this email
	# the values should be one of the following:
	# NOTE: there are not full values, but should match the first part of the string..	
	#  List-Id: CVS commit messages for the ports tree
	#  List-Id: CVS commit messages for the doc and www trees
	#  List-Id: "SVN commit messages for the entire src tree

	my $ListId = FreshPorts::ProcessMail::myGetList_Id($message);
	if (!defined($ListId)) {
		FreshPorts::Utilities::ReportErrorEmailNoPrint('err', "No List-Id found for this commit message (" . $Message_Subject . ").\n\nIs this a corrupted commit or email?", 1)
	}

#	print 'Message-Id: ' . $MessageId       . "\n";
#	print 'List-Id: '    . $ListId          . "\n";
#	print 'Subject: '    . $Message_Subject . "\n";

	my $found = 0;
	my $ListProperties = FreshPorts::Branches::ListProperties($ListId);
	if (defined($ListProperties))
	{
		$found = 1;
		my $process = $ListProperties->{'process'};
		eval "use FreshPorts::$process";
	}

	if (!$found) {
		FreshPorts::Utilities::ReportErrorEmailNoPrint('err', "This List-Id/Message-Id combination is not known to this script. List-Id='" . 
			$ListId . "' Message-Id='" . $MessageId . "'\n\nIs this a corrupted commit or email? Perhaps trailing ^M on the lines.", 1)
	}

	# Get the data
	my ($Data_ref) = &GetData($message);

	# Create the XML
	&WriteXML($Data_ref);

	# Done!  Woo woo!
	exit;
}
