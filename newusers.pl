#!/usr/local/bin/perl -w
#
# $Id: newusers.pl,v 1.5 2011-08-22 01:39:35 dan Exp $
#
# Copyright (c) 2001-2006 DVL Software
#

use strict;
use DBI;

use FreshPorts::database;
use FreshPorts::commit_log_ports_ignore;
use FreshPorts::system_status;

sub SendNotice($;$;$) {
   my $StartDate = shift;
   my $EndDate   = shift;
   my $msgbody   = shift;

   my $From         = 'FreshPorts Daemon <FreshPorts@FreshPorts.org>';
   my $To           = 'Dan Langille <dan@langille.org>';
   my $CC           = '';
   my $Subject      = "FreshPorts -- new users  - $StartDate to $EndDate";

   my %ExtraHeaders = (
     'Auto-Submitted'        => 'auto-generated',
     'Precedence'            => 'bulk',
     'X-FreshPorts-NewUsers' => "$StartDate to $EndDate"
   );

   my $Body = "The following users were added in this period:

$msgbody --

";

   FreshPorts::email::SendMail($From, $To, $CC, $Subject, $Body, \%ExtraHeaders);
}

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

if (($#ARGV+1) == 2) {
#   print "there are 2 arguments\n";

   my $StartDate = $ARGV[0];
   my $EndDate   = $ARGV[1];

   my $dbh = FreshPorts::Database::GetDBHandle($FreshPorts::Constants::DB_ConnectionType => $FreshPorts::Constants::DB_ConnectionType_ReadOnly);
   if (!$dbh) {
      print " connect failed\n";
   }
   my $sql = "select id, name, email, ip_address, firstlogin \
              from users \
              where date_trunc('day', firstlogin) between '$StartDate' and '$EndDate'
              order by id";

#   print "sql is $sql\n";

   my $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   my $msgbody = '';

   while (my @row=$sth->fetchrow_array) {
      $msgbody .= $row[0] . " : " . $row[1] . " : " . $row[2] . " : " . $row[3] . " : " . $row[4] . "\n";
   }

#   print "msgbody = '" . $msgbody . "'\n";
   if ($msgbody ne '') {
      SendNotice($StartDate, $EndDate, $msgbody);
   }

   $dbh->disconnect();
} else {
   print "please specify a start date and an end date\n";
}
