#!/usr/local/bin/perl -w

use strict;
use FreshPorts::constants;
use FreshPorts::database; 
use DBI;

require Sys::Syslog;

Sys::Syslog::setlogsock('unix');
Sys::Syslog::openlog('FreshPorts', 'cons, pid', 'user');

my $emailToCheck = $ARGV[0];

my $dbh = FreshPorts::Database::GetDBHandle();

my $sql = "select count(email) 
             from users, report_subscriptions 
            where report_subscriptions.user_id = users.id
              and report_id = $FreshPorts::Constants::ReportIDMaintainerNotification
              and lower(email) = lower('$emailToCheck')";

print "\$sql='$sql'\n";

my $sth = $dbh->prepare($sql);
$sth->execute ||
        die "Could not execute SQL $sql ... maybe invalid?";

my @row = $sth->fetchrow_array;

Sys::Syslog::syslog('warning', "checkaddress is checking $ARGV[0] and finding @row[0]");

$sth->finish();
$dbh->disconnect();

exit ($row[0] = 0);
