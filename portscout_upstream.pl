#!/usr/local/bin/perl -w
#
# Copyright (c) 2026 Dan Langille
#
# Load portscout's results into port_upstream, for the port page (#626).
# portscout_upstream.sh fetches the file and runs this; see there.
#
#   perl portscout_upstream.pl --filename=FILE [--dry-run]
#
# The file is a JSON array with one object per port.  The fields used:
#
#   cat, name    the port
#   ver          the version portscout found in the tree: DISTVERSION, or
#                PORTVERSION where the port sets that instead
#   newver       a newer version found upstream, or null
#   newurl       the newer distfile
#   checked      when portscout last looked upstream: "2026-11-07 02:01 GMT"
#   discovered   when portscout first found newver
#   maintainer
#
# A port gets a row when all of these hold:
#
#   1. ver is ports.version, either as it stands or once converted the way
#      Mk/bsd.port.mk makes PORTVERSION from DISTVERSION.  Otherwise
#      portscout was looking at some other version than ours, most often
#      because the port has been updated since it last looked.
#
#      Both, because a port which sets PORTVERSION itself (1.2a) matches
#      only as it stands; the conversion would make it 1.2.a.  In November
#      2026 this matched 35,456 of the 35,467 ports both sides know about.
#
#   2. newver is set.
#
#   3. newver is newer than ports.version, according to pkg version -t,
#      once anything before its first digit is dropped (v3.0.12,
#      release-0.3.3) and it is converted the same way.
#
#   4. portscout checked it within the last $MaxAgeDays days.
#
# Ports which no longer qualify lose their row.  Each port whose row is
# added, changed, or removed has its cached pages cleared.
#
# --dry-run reads the database but changes nothing; it prints the changes
# it would have made.
#

use strict;

use Getopt::Long;
use JSON::PP;
use Time::Local qw(timegm);
use Time::HiRes qw(time);

use FreshPorts::database;
use DBI;

require Sys::Syslog;
use FreshPorts::config;
use FreshPorts::system_status;

# portscout's check is older than this: leave the port out
my $MaxAgeDays = 14;

# A file with fewer ports than this is broken or cut short, not a sudden
# drop in the size of the ports tree.  November 2026: 35,489.
my $MinEntries = 20000;

# More than this share of the rows going in one run is more likely a fault
# than that many ports caught up overnight.  Only checked once the table
# has enough rows to say.
my $MaxDeleteShare = 0.5;
my $MinRowsForShare = 100;

# shown in --dry-run, per kind of change
my $DryRunShow = 20;

my $Pkg = '/usr/sbin/pkg';

my $Filename;
my $DryRun = 0;
GetOptions('filename=s' => \$Filename, 'dry-run' => \$DryRun) && defined($Filename)
	or die "usage: $0 --filename=FILE [--dry-run]\n";

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$DryRun && !$SystemStatus->Online()) {
	exit 0;
}

FreshPorts::Utilities::InitSyslog();

# PORTVERSION from DISTVERSION, as Mk/bsd.port.mk does it:
#   ${DISTVERSION:tl:C/([a-z])[a-z]+/\1/g:C/([0-9])([a-z])/\1.\2/g:C/:(.)/\1/g:C/[^a-z0-9+]+/./g}
sub portversion {
	my ($v) = @_;

	$v = lc($v);
	$v =~ s/([a-z])[a-z]+/$1/g;
	$v =~ s/([0-9])([a-z])/$1.$2/g;
	$v =~ s/:(.)/$1/g;
	$v =~ s/[^a-z0-9+]+/./g;

	return $v;
}

# true when pkg says $x is newer than $y
sub newer {
	my ($x, $y) = @_;

	open(my $fh, '-|', $Pkg, 'version', '-t', $x, $y)
		or die "could not run $Pkg version -t: $!";
	my $result = <$fh>;
	close($fh);
	die "$Pkg version -t '$x' '$y' failed\n" if !defined($result);
	chomp($result);

	return $result eq '>';
}

# "2026-11-07 02:01 GMT" (checked) or "2025-10-19 03:31:44.708142"
# (discovered) to seconds since the epoch, or undef.  discovered carries no
# zone; it is taken as UTC, as checked is.
sub epoch {
	my ($t) = @_;

	return undef if !defined($t);
	return undef if $t !~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d)(?::(\d\d))?/;

	return eval { timegm(defined($6) ? $6 : 0, $5, $4, $3, $2 - 1, $1) };
}

sub show {
	my (@fields) = @_;

	return join(' ', map { defined($_) ? $_ : '-' } @fields);
}

my $Start = time();

#
# the file
#
open(my $fh, '<:raw', $Filename) or die "could not open $Filename: $!\n";
my $Text = do { local $/; <$fh> };
close($fh);

my $Entries = eval { JSON::PP->new->utf8->decode($Text) };
die "$Filename is not valid JSON: $@" if !defined($Entries);
die "$Filename is not a JSON array\n" if ref($Entries) ne 'ARRAY';
die sprintf("%s lists %d ports, fewer than %d; not loading it\n", $Filename, scalar(@$Entries), $MinEntries)
	if @$Entries < $MinEntries;
undef $Text;

my $dbh = FreshPorts::Database::GetDBHandle();

#
# our ports
#
my %Ports;
my $sth = $dbh->prepare('SELECT id, category, name, version FROM ports_active');
$sth->execute() or die 'could not read ports_active';
while (my ($id, $category, $name, $version) = $sth->fetchrow_array()) {
	$Ports{"$category/$name"} = [ $id, $version ];
}
$sth->finish();

#
# what we have now
#
my @Columns = qw(port_version newver newurl maintainer discovered checked);
my %Have;
$sth = $dbh->prepare('SELECT port_id, port_version, newver, newurl, maintainer,
                             extract(epoch FROM discovered)::bigint,
                             extract(epoch FROM checked)::bigint
                        FROM port_upstream');
$sth->execute() or die 'could not read port_upstream';
while (my ($port_id, @row) = $sth->fetchrow_array()) {
	$Have{$port_id} = \@row;
}
$sth->finish();

#
# what we should have
#
my $Oldest = time() - $MaxAgeDays * 24 * 60 * 60;

my %Want;
my %Count = map { $_ => 0 } qw(not_ours no_newver version_differs stale not_newer);

foreach my $entry (@$Entries) {
	next if ref($entry) ne 'HASH' || !defined($entry->{cat}) || !defined($entry->{name});

	my $port = $Ports{"$entry->{cat}/$entry->{name}"};
	if (!$port) {
		$Count{not_ours}++;
		next;
	}
	my ($port_id, $version) = @$port;

	my $newver = $entry->{newver};
	if (!defined($newver) || $newver eq '') {
		$Count{no_newver}++;
		next;
	}

	my $ver = $entry->{ver};
	if (!defined($version) || !defined($ver) || ($ver ne $version && portversion($ver) ne $version)) {
		$Count{version_differs}++;
		next;
	}

	my $checked = epoch($entry->{checked});
	if (!defined($checked) || $checked < $Oldest) {
		$Count{stale}++;
		next;
	}

	(my $compare = $newver) =~ s/^[^0-9]+//;
	if ($compare eq '' || !newer(portversion($compare), $version)) {
		$Count{not_newer}++;
		next;
	}

	$Want{$port_id} = [ $version, $newver, $entry->{newurl}, lc($entry->{maintainer} // ''),
	                    epoch($entry->{discovered}), $checked ];
}

#
# the differences
#
my (@Insert, @Update, @Delete);
foreach my $port_id (keys %Want) {
	if (!$Have{$port_id}) {
		push(@Insert, $port_id);
	} elsif (show(@{$Have{$port_id}}) ne show(@{$Want{$port_id}})) {
		push(@Update, $port_id);
	}
}
foreach my $port_id (keys %Have) {
	push(@Delete, $port_id) if !$Want{$port_id};
}

my $HaveCount = scalar(keys %Have);
if ($HaveCount >= $MinRowsForShare && @Delete > $HaveCount * $MaxDeleteShare) {
	die sprintf("would remove %d of the %d rows in port_upstream, more than %d%%; not loading %s\n",
		scalar(@Delete), $HaveCount, $MaxDeleteShare * 100, $Filename);
}

my $Summary = sprintf('%d ports in the file: %d not in FreshPorts, %d with no newer version, %d at another version than ours, %d not checked in %d days, %d not newer than ours; %d to show. %d added, %d changed, %d removed',
	scalar(@$Entries), $Count{not_ours}, $Count{no_newver}, $Count{version_differs},
	$Count{stale}, $MaxAgeDays, $Count{not_newer}, scalar(keys %Want),
	scalar(@Insert), scalar(@Update), scalar(@Delete));

if ($DryRun) {
	my %Name = map { $Ports{$_}[0] => $_ } keys %Ports;
	foreach my $kind (['added', \@Insert], ['changed', \@Update], ['removed', \@Delete]) {
		my ($label, $ids) = @$kind;
		my @ids = sort { $Name{$a} cmp $Name{$b} } @$ids;
		printf("%s: %d\n", $label, scalar(@ids));
		foreach my $port_id (@ids[0 .. ($#ids < $DryRunShow - 1 ? $#ids : $DryRunShow - 1)]) {
			printf("  %-50s %s\n", $Name{$port_id} // $port_id,
				$label eq 'removed' ? show(@{$Have{$port_id}}[0, 1]) : show(@{$Want{$port_id}}[0, 1]));
		}
	}
	print "$Summary\n";
	$dbh->rollback();
	$dbh->disconnect();
	exit 0;
}

#
# make the changes, all or nothing
#
my $insert = $dbh->prepare('INSERT INTO port_upstream (port_id, port_version, newver, newurl, maintainer, discovered, checked)
                            VALUES (?, ?, ?, ?, ?, to_timestamp(?), to_timestamp(?))');
my $update = $dbh->prepare('UPDATE port_upstream
                               SET port_version = ?, newver = ?, newurl = ?, maintainer = ?,
                                   discovered = to_timestamp(?), checked = to_timestamp(?)
                             WHERE port_id = ?');
my $delete = $dbh->prepare('DELETE FROM port_upstream WHERE port_id = ?');

foreach my $port_id (@Insert) {
	$insert->execute($port_id, @{$Want{$port_id}}) or die "could not add port $port_id";
}
foreach my $port_id (@Update) {
	$update->execute(@{$Want{$port_id}}, $port_id) or die "could not change port $port_id";
}
foreach my $port_id (@Delete) {
	$delete->execute($port_id) or die "could not remove port $port_id";
}

#
# Clear the cached pages of every port whose row changed, as
# process_updating.pl does.  The notify is delivered on commit.
#
my @Changed = (@Insert, @Update, @Delete);
if (@Changed) {
	$sth = $dbh->prepare('INSERT INTO cache_clearing_ports (port_id, category, port)
	                      SELECT id, category, name
	                        FROM ports_active
	                       WHERE id = ANY(?)
	                          ON CONFLICT DO NOTHING');
	$sth->execute(\@Changed) or die 'could not add to cache_clearing_ports';
	$dbh->do('NOTIFY port_updated') or die 'could not notify port_updated';
}

$dbh->commit();
$dbh->disconnect();

$Summary .= sprintf(', %.1f s', time() - $Start);

Sys::Syslog::syslog('notice', "port_upstream: $Summary");
print "$Summary\n";

exit 0;
