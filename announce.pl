#!/usr/local/bin/perl -w
#
# $Id: announce.pl,v 1.6 2006-12-17 12:03:58 dan Exp $
#
# Copyright (c) 1999-2006 DVL Software
#

use strict;
use DBI;
use FreshPorts::database;
use FreshPorts::constants;
use FreshPorts::email;

my @USERS;
my $sql;
my $sth;
my @row;
my $Bcc;

my $ReportID = $FreshPorts::Constants::ReportIDAnnouncements;


sub SendAnnouncement($) {

	my $To      = shift;
	my $From    = 'FreshPorts Announcement Daemon <FreshPorts-Announce@FreshPorts.org>';
	my $CC      = '';
	my $Subject = 'HEADS UP: FreshPorts announcement';
	my %ExtraHeaders = (
          'Auto-Submitted'            => 'auto-generated',
          'Precedence'                => 'bulk',
          'X-FreshPorts-Announcement' => 'HEADS UP',
        );



	my $Body = "Folks,

FreshPorts - changes to email headers

Starting on Saturday July 16, the report notifications that go
out from FreshPorts will contain a header to indicate it was
automatically generated.  The main purpose of this is so I don't
get replies from your vacation programs.

The main reason I'm writing is in case of any side effects this
header may have on any scripts you might be running.

Cheers 

--

You are receiving this message as part of the service
you joined at https://www.FreshPorts.org/ but if you no longer
wish to receive such messages, please go to
https://www.FreshPorts.org/report-subscriptions.php

If a problem occurs, please send details, including the email
address in question, to postmaster\@freshports.org
";

	FreshPorts::email::SendMail($From, $To, $CC, $Subject, $Body, \%ExtraHeaders);
}

sub SendToEachListMember($) {

   my $dbh = shift;
   my $sth;
   my $sql;

   #
   # get a list of ports to update
   #
   # the following line restricts mailouts to just me.
   #               and users.id                      = 2

   $sql = "select users.email
             from users, report_subscriptions
            where length(users.email)            > 0
              and report_subscriptions.user_id   = users.id
              and emailbouncecount               = 0
              and report_subscriptions.report_id = $ReportID";

   print "sql is $sql\n";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   while (@row=$sth->fetchrow_array) {
      SendAnnouncement($row[0]);
   }
}

      my $dbh = FreshPorts::Database::GetDBHandle();

      SendToEachListMember($dbh);

      $dbh->disconnect();

      print "\nmessage sent to users\n";

