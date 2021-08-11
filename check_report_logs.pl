#!/usr/local/bin/perl

use strict;
use FreshPorts::constants;
use FreshPorts::database;
use DBI;

my @Reports = (
    {
        frequency => 'D',
        interval  => '25 hours',
    },
    {
        frequency => 'W',
        interval  => '8 days',
    },
    {
        frequency => 'F',
        interval  => '18 days',
    },
    {
        frequency => 'M',
        interval  => '32 days',
    },
);

my $dbh = FreshPorts::Database::GetDBHandle($FreshPorts::Constants::DB_ConnectionType => $FreshPorts::Constants::DB_ConnectionType_ReadOnly);
if (!$dbh->{Active}) {
  print "No database connection";
  return 2;
}

my $ReportsNotSent = '';

for my $href ( @Reports ) {
#    print "{ ";
#    print "frequency = $href->{frequency}, interval = $href->{interval}";
#    print "}\n";

    my $sql = "
select R.name, to_char(RLL.last_sent, 'YYYY-MM-DD HH:MI') as last_sent
  from report_log_latest RLL join reports R on RLL.report_id = R.id
 where RLL.frequency = '" . $href->{frequency} . "' and (RLL.last_sent < now() - interval '" . $href->{interval} . "') order by R.name";
    

#    print $sql . "\n";

    my $sth = $dbh->prepare($sql);
    $sth->execute || die "Could not execute SQL $sql ... maybe invalid";

    my $row;
    while ($row = $sth->fetchrow_hashref()) {
      $ReportsNotSent .= $href->{frequency} . ' ' . $row->{name} . ': last sent on ' . $row->{last_sent} . "\n";
    }

    $sth->finish();

}

$dbh->disconnect();

if ($ReportsNotSent eq '') {
    print 'All reports are up to date'. "\n";
    exit 0;
} else {
    print $ReportsNotSent;
    exit 2;
}
