#!/usr/local/bin/perl -w
#
# $Id: report-new-ports.pl,v 1.4 2007-04-19 22:33:12 dan Exp $
#
# Copyright (c) 2001-2006 DVL Software
#

use strict;

use FreshPorts::config;
use FreshPorts::email;

sub SendTestEmail($;$) {

	my $To            = shift;
	my $Body          = shift;

	my $From         = 'FreshPorts Watch Daemon <FreshPorts-Watch@FreshPorts.org>';
	my $Subject      = "FreshPorts test email";
	my %ExtraHeaders = (
		'Auto-Submitted'       => 'auto-generated',
		'Precedence'           => 'bulk',
		'X-FreshPorts-testing' => 'this is a test email',
	);
	my $CC = '';

	FreshPorts::email::SendMail($From, $To, $CC, $Subject, $Body, \%ExtraHeaders);
}

SendTestEmail($FreshPorts::Config::SystemOwnerEmail, "This is the body of the test message.  Ride fast.  Take chances.");

print "finish " . `date "+%Y-%m-%d %H:%M:%S"`;
