#!/usr/local/bin/perl -w
#
# Copyright (c) 1999-2026 Dan Langille
#

# Refresh each port named in a file, and say why its version can move.
#
# Written for the output of compare-index.sh, which finds ports whose version
# in the database no longer matches the ports tree.
#
# usage: refresh-listed-ports.pl [--dryrun] [--debug] FILE
#
#   FILE         one category/port per line.  - reads standard input.  Blank
#                lines are ignored, as is anything after a #, so a list can
#                be annotated.
#   --dryrun     report what would happen and write nothing to the database.
#                Everything else runs: the port is looked up, its Makefiles
#                are read, and the version and the reason are reported.
#                Takes no argument, unlike process_default_versions.pl.
#   --debug      print the SQL used to look a port up.
#
# for example:
#
#   refresh-listed-ports.pl /var/db/freshports/cache/spooling/refresh.txt
#   refresh-listed-ports.pl --dryrun refresh.txt
#   compare-index.sh ... | refresh-listed-ports.pl -
#
# Each port reports the version it held, the version the Makefile gives, and
# where that version comes from.  Both go to the terminal and to syslog:
#
#   devel/geany-plugin-vc: 2.0 -> 2.1
#   devel/geany-plugin-vc: PORTVERSION set in devel/geany-plugins/Makefile (outside this port): 2.1
#
# HEAD only, as process_default_versions.pl is.
#
# A refresh reads the Makefiles as they are on disk, so what it writes
# describes the tree in whatever state it is in when this runs.
#

use strict;
use FreshPorts::branches;
use FreshPorts::port;
use DBI;
use FreshPorts::config;
use FreshPorts::constants;
use FreshPorts::database;
use FreshPorts::utilities;
use FreshPorts::system_status;
use File::Basename;
use File::Spec;
use Getopt::Long;

# Report() appends the script directory, so the basename is enough to say
# which script in that directory did the talking.
my $ME = basename($0);

my $dbh;
my $sql;
my $sth;

my $dryrun = 0;
my $debug  = 0;

if (!GetOptions('debug' => \$debug, 'dryrun' => \$dryrun)) {
	exit;
}

#
# process_default_versions.pl spells these --dryrun y and --debug y, so a
# stray y is a likely mistake.  Without this it becomes the filename and the
# error says only that y cannot be read, which explains nothing.
#
if (defined($ARGV[0]) && ($ARGV[0] eq 'y' || $ARGV[0] eq 'n')) {
	print("--dryrun and --debug take no argument; drop the '$ARGV[0]'\n");
	exit 1;
}

my $filename = shift;

if (!defined($filename)) {
	print("usage: $0 [--dryrun] [--debug] FILE\n");
	print("       FILE       one category/port per line, or - for stdin\n");
	print("       --dryrun   report what would happen, write nothing\n");
	print("       --debug    print the SQL used to look a port up\n");
	exit 1;
}

#
# version, revision and epoch assembled the way bsd.port.mk assembles
# PKGVERSION: ${PORTVERSION}[_${PORTREVISION}][,${PORTEPOCH}], with the
# revision and the epoch left off when they are unset or zero.
#
# A NULL revision or epoch fetches as undef, hence the defined() tests.
#
sub PkgVersion {
	my $port = shift;

	my $version  = defined($port->{version})   ? $port->{version}   : '';
	my $revision = defined($port->{revision})  ? $port->{revision}  : '';
	my $epoch    = defined($port->{portepoch}) ? $port->{portepoch} : '';

	$version .= '_' . $revision if ($revision ne '' && $revision ne '0');
	$version .= ',' . $epoch    if ($epoch    ne '' && $epoch    ne '0');

	return $version;
}

#
# Where a port's version comes from.
#
# A port whose version moves without a commit to its own directory got that
# version from somewhere else: a master port, an included Makefile, or a
# default version in Mk.  This asks make which files it read, looks in those
# files for what assigns the version -- PORTVERSION, PORTREVISION, PORTEPOCH
# and the DISTVERSION forms -- and follows one level of indirection --
# PORTVERSION=${PYTHON_DEFAULT} is only half an answer without knowing where
# PYTHON_DEFAULT is set.
#
# It reports what it can see textually.  A version built by a shell escape,
# or by conditionals, is reported as assigned in that file with no further
# explanation, which is honest rather than a guess.
#
my $MAKE = '/usr/bin/make';   # base system make; the ports tree needs no other

my %MakefileCache;            # absolute path -> [ lines ]

sub MakefileLines {
	my $pathname = shift;

	if (!exists($MakefileCache{$pathname})) {
		my @lines;

		if (open(my $FILE, '<', $pathname)) {
			@lines = <$FILE>;
			close($FILE);
		}

		$MakefileCache{$pathname} = \@lines;
	}

	return $MakefileCache{$pathname};
}

#
# The makefiles make read for this port, as [ repo-relative, absolute ]
# pairs, in the order it read them.  Those outside the ports tree -- base
# system mk files, make.conf -- are dropped: they are not what moves a port.
#
# make runs on the host against the jail's tree, as compare-index.sh does.
# No jexec, so no sudo.  The list form of open() keeps a shell out of it.
#
sub MakefilesRead {
	my $origin   = shift;
	my $portsdir = $FreshPorts::Config::JailBaseDir . $FreshPorts::Config::PortsDir;

	my $MAKEFILES;
	if (!open($MAKEFILES, '-|', $MAKE, '-C', "$portsdir/$origin",
	                             "PORTSDIR=$portsdir", '-V', '.MAKE.MAKEFILES')) {
		return ();
	}

	my $line = <$MAKEFILES>;
	close($MAKEFILES);

	return () if (!defined($line));

	chomp($line);

	my @files;
	my %seen;

	foreach my $file (split(/\s+/, $line)) {
		next if ($file eq '');

		# 'Makefile' is relative to the port; others can hold a ..
		my $absolute = ($file =~ m|^/|) ? $file : "$portsdir/$origin/$file";
		$absolute = File::Spec->canonpath($absolute);
		1 while ($absolute =~ s|/[^/]+/\.\./|/|);

		next if ($absolute !~ m|^\Q$portsdir\E/(.+)$|);

		my $relative = $1;
		next if ($seen{$relative}++);

		push @files, [ $relative, $absolute ];
	}

	return @files;
}

sub WhyVersionComesFromWhere {
	my $origin = shift;

	my @files = MakefilesRead($origin);

	if (!@files) {
		return ("could not ask make which files it read for $origin");
	}

	my @why;

	foreach my $file (@files) {
		my ($relative, $absolute) = @{$file};

		#
		# Mk holds the framework, which every port in the tree reads.  Its
		# own definitions -- bsd.port.mk deriving PORTVERSION from
		# DISTVERSION and back again -- are true of every port and so
		# explain nothing about why this one moved.  Skip them here.
		#
		# They are still searched when following a reference: PYTHON_DEFAULT
		# really is set in Mk/bsd.default-versions.mk, and that is an answer.
		#
		next if ($relative =~ m|^Mk/|);

		foreach my $line (@{MakefileLines($absolute)}) {
			# PORTREVISION and PORTEPOCH are part of the version too, and
			# a revision bumped in a master port moves every slave without
			# a commit to any of them.
			#
			# ?= += := != as well as plain =; != is a shell escape, whose
			# value we can show but cannot follow
			next if ($line !~ /^\s*(PORTVERSION|PORTREVISION|PORTEPOCH|DISTVERSIONPREFIX|DISTVERSIONSUFFIX|DISTVERSION)\s*[?+:!]?=\s*(.*?)\s*$/);

			my ($variable, $value) = ($1, $2);

			# the whole point: is this the port's own Makefile, or not?
			my $where = ($relative =~ m|^\Q$origin\E/|) ? '' : ' (outside this port)';

			push @why, "$variable set in $relative$where: $value";

			# follow one level: ${FOO} on the right hand side
			my %referenced;
			while ($value =~ /\$[\{\(](\w+)[\}\)]/g) {
				$referenced{$1} = 1;
			}

			foreach my $reference (sort keys %referenced) {
				foreach my $other (@files) {
					my ($otherrelative, $otherabsolute) = @{$other};

					if (grep { /^\s*\Q$reference\E\s*[?+:!]?=/ } @{MakefileLines($otherabsolute)}) {
						push @why, "  $reference set in $otherrelative";
					}
				}
			}
		}
	}

	if (!@why) {
		push @why, "nothing in the files make read assigns the version textually";
	}

	return @why;
}

my $LIST;
if ($filename eq '-') {
	$LIST = \*STDIN;
} else {
	open($LIST, '<', $filename) || die "$0: cannot read $filename: $!\n";
}

FreshPorts::Utilities::InitSyslog();

print("$0 starts\n");

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

$dbh = FreshPorts::Database::GetDBHandle();

my $currentBranch = $FreshPorts::Constants::HEAD;
# start off on head
FreshPorts::Branches::SetBranchInDB($dbh, $currentBranch);

$sql = "SET CLIENT_ENCODING TO 'ISO-8859-1';
        select P.id as port_id
          from element_pathname EP, ports P
         where pathname = ?
           and EP.element_id = P.element_id";

if ($debug) {
	print "\$dryrun='$dryrun'\n";
	print "sql = $sql\n";
}

$sth = $dbh->prepare($sql);

my $refreshed = 0;
my $dryrunned = 0;
my $unchanged = 0;
my $missed    = 0;
my $failed    = 0;
my $notfound  = 0;

while (my $category_port = <$LIST>) {
	chomp($category_port);

	# ignore blank lines, and comments, so a list can be annotated
	$category_port =~ s/#.*//;
	$category_port =~ s/^\s+|\s+$//g;
	next if ($category_port eq '');

	if ($category_port !~ m|^[^/]+/[^/]+$|) {
		FreshPorts::Utilities::ReportError('warning', "not a category/port: '$category_port'", 0);
		$failed++;
		next;
	}

	# Ports_HEAD_commit contains a trailing slash
	my $element_pathname = $FreshPorts::Constants::Ports_HEAD_commit . $category_port;

	print("$0 working on '$category_port' ('$element_pathname')\n");

	$sth->execute($element_pathname) ||
		FreshPorts::Utilities::ReportError('warning', "Could not execute SQL $sql ... maybe invalid? with '$element_pathname'", 1);

	my $row     = $sth->fetchrow_hashref();
	my $port_id = $row->{port_id};

	if (!defined($port_id)) {
		FreshPorts::Utilities::ReportError('warning', "No such port on $currentBranch: '$category_port'", 0);
		$notfound++;
		next;
	}

	print "now processing $category_port with port_id = $port_id\n";

	# We shall assume 'git' because the code needs a value.
	#
	my $port = FreshPorts::Port->new($dbh, 'git');

	$port->{id} = $port_id;
	if ($port->FetchByID()) {
		# what the database holds now, before the Makefile is read
		my $was = PkgVersion($port);

		my $result = $port->RefreshFromFiles($currentBranch, $currentBranch);

		if ($result == 0) {
			# and what the Makefile says.  Both are printed whether or not
			# they differ: a port which comes back unchanged is worth seeing,
			# because it means the refresh was not what it needed.
			my $now = PkgVersion($port);

			# to the terminal for whoever is watching, and to syslog so the
			# scheduled runs leave a record of what they changed
			my $change = sprintf("%s %s: %s -> %s", $ME, $category_port, $was, $now);

			print $change . "\n";
			FreshPorts::Utilities::Report('info', $change);

			#
			# Why this port's version can move without a commit to its own
			# directory.  Reported whether or not it moved this time: the
			# reason is what makes the list worth reading.
			#
			my @why = WhyVersionComesFromWhere($category_port);

			foreach my $why (@why) {
				my $reason = "$ME $category_port: $why";

				print $reason . "\n";
				FreshPorts::Utilities::Report('info', $reason);
			}

			# the lines which name an assignment, as opposed to a reference
			# we followed or a note that we found nothing
			my @assignments = grep { /^(?:PORTVERSION|PORTREVISION|PORTEPOCH|DISTVERSION)/ } @why;
			my $outside     = grep { /\(outside this port\)/ } @assignments;

			# An assignment whose value is a reference -- PORTVERSION=
			# ${PYTHON_DEFAULT} -- sits inside the port but takes its value
			# from wherever that variable is set.  Only a literal value can
			# tell us a commit to this port must have changed it.
			my $referenced  = grep { /\$[\{\(]/ } @assignments;

			if ($was eq $now) {
				#
				# The database already held what the Makefile says, so this
				# port never needed refreshing.  compare-index.sh listed it
				# because the INDEX disagrees with the ports tree -- the two
				# were read at different commits -- which is a fact about
				# those two, not about the database.
				#
				my $nochange = "$ME $category_port: no change needed; the INDEX and the ports tree disagree, not the database";

				print $nochange . "\n";
				FreshPorts::Utilities::Report('notice', $nochange);
				$unchanged++;
			} elsif (@assignments && !$outside && !$referenced) {
				#
				# The version moved and nothing outside this port sets it, so
				# only a commit to this port's own directory can have moved
				# it -- and we are finding out from the INDEX rather than
				# from that commit.  Commit processing missed it.
				#
				FreshPorts::Utilities::ReportError('err',
					"$ME $category_port: version changed to $now and is set only within the port: a commit to $category_port was missed", 0);
				$missed++;
			}

			#
			# A port whose version did not move is still saved -- other
			# fields may have changed -- but it is counted as needing no
			# change rather than as a refresh, so the two counts are
			# separate facts which add up to the ports processed.
			#
			if ($dryrun) {
				# everything above reads; save() and commit() are the only
				# things which write, so a dry run simply stops here
				$dbh->rollback();
				$dryrunned++ if ($was ne $now);
			} else {
				$port->save($currentBranch);
				# commit each port on its own, so a failure part way through
				# does not throw away the ports already done
				$dbh->commit();
				$refreshed++ if ($was ne $now);
			}
		} else {
			$dbh->rollback();
			FreshPorts::Utilities::ReportError('warning', "Could not refresh '$category_port' (result $result)", 0);
			$failed++;
		}
	} else {
		FreshPorts::Utilities::ReportError('warning', "Could not Fetch port ($category_port)", 0);
		$failed++;
	}
}

close($LIST) if ($filename ne '-');

$sth->finish();

my $tally = "$ME ends: $refreshed refreshed, $unchanged needed no change, $failed failed, $notfound not found";

if ($dryrun) {
	$tally = "$ME ends: $dryrunned would be refreshed, $unchanged needed no change, $failed failed, $notfound not found (dry run, nothing written)";
}

print $tally . "\n";
FreshPorts::Utilities::Report('info', $tally);

#
# Said again on its own, because a missed commit is not a counter anyone
# should have to notice at the end of a line.
#
if ($missed) {
	FreshPorts::Utilities::ReportError('err',
		"$ME $missed port(s) changed version with no commit processed for them: commits have been missed", 0);
}

$dbh->commit();
$dbh->disconnect();

