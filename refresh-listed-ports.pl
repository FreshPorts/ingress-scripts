#!/usr/local/bin/perl -w
#
# Copyright (c) 1999-2026 DVL Software
#

# Refresh each port named in a file, and say why its version can move.
#
# Written for the output of compare-index.sh, which finds ports whose version
# in the database no longer matches the ports tree.
#
# usage: refresh-listed-ports.pl [--dryrun y] [--debug y] FILE
#
#   FILE         one category/port per line.  - reads standard input.  Blank
#                lines are ignored, as is anything after a #, so a list can
#                be annotated.
#   --dryrun y   report what would happen and write nothing to the database.
#                Everything else runs: the port is looked up, its Makefiles
#                are read, and the version and the reason are reported.
#   --debug y    print the SQL used to look a port up.
#
# for example:
#
#   refresh-listed-ports.pl /var/db/freshports/cache/spooling/refresh.txt
#   refresh-listed-ports.pl --dryrun y refresh.txt
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
# The ports tree has to be on main before this runs.  A refresh reads the
# Makefiles as they are on disk, so a tree left detached at some older commit
# -- which is how the ingress often leaves it -- would write those older
# versions into the database and undo the very thing this is fixing.
#
# Do NOT git pull or git fetch to satisfy that.  The ingress owns the state of
# that tree, and moving it forward underneath in-flight commit processing is
# worse than not running at all.  Leave the tree to whatever puts it back on
# main, and run this afterwards.
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

my $dryrun = 'n';
my $debug  = 'n';

if (!GetOptions('debug=s' => \$debug, 'dryrun=s' => \$dryrun)) {
	exit;
}

if ($dryrun ne 'y' && $dryrun ne 'n') {
	print("--dryrun must be y or n\n");
	exit;
}

my $filename = shift;

if (!defined($filename)) {
	print("usage: $0 [--dryrun y] [--debug y] FILE\n");
	print("       FILE       one category/port per line, or - for stdin\n");
	print("       --dryrun y report what would happen, write nothing\n");
	print("       --debug y  print the SQL used to look a port up\n");
	exit 1;
}

#
# Is the ports tree on main?  Returns undef when it is, and the reason why
# not when it is not, so the caller can log that reason rather than a
# generic refusal: which branch, or which commit, is the only thing worth
# having in the log.
#
# .git/HEAD is read directly rather than shelling out to git: the tree is
# owned by root, so git needs either privilege or a safe.directory exception,
# and this needs neither.  On a branch the file holds 'ref: refs/heads/
# <branch>'; detached, it holds a bare commit hash.
#
sub WhyPortsTreeIsNotOnMain {
	my $portsdir = $FreshPorts::Config::JailBaseDir . $FreshPorts::Config::PortsDir;
	my $headfile = $portsdir . '/.git/HEAD';

	my $HEAD;
	if (!open($HEAD, '<', $headfile)) {
		return "cannot read $headfile: $!";
	}

	my $ref = <$HEAD>;
	close($HEAD);

	if (!defined($ref)) {
		return "$headfile is empty";
	}

	chomp($ref);

	if ($ref eq 'ref: refs/heads/main') {
		return undef;
	}

	if ($ref =~ m|^ref: refs/heads/(.*)$|) {
		return "$portsdir is on branch '$1', not main";
	}

	return "$portsdir is detached at $ref, not on main";
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
# files for what assigns the version, and follows one level of indirection --
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

		foreach my $line (@{MakefileLines($absolute)}) {
			# ?= += := != as well as plain =; != is a shell escape, whose
			# value we can show but cannot follow
			next if ($line !~ /^\s*(PORTVERSION|DISTVERSIONPREFIX|DISTVERSIONSUFFIX|DISTVERSION)\s*[?+:!]?=\s*(.*?)\s*$/);

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

my $notonmain = WhyPortsTreeIsNotOnMain();

if (defined($notonmain)) {
	#
	# Both lines are logged as well as printed.  A scheduled run which
	# refuses has to say what the tree was doing, and whoever reads that
	# in syslog needs the same warning as whoever reads it on a terminal:
	# the fix is to wait, not to move the tree.
	#
	FreshPorts::Utilities::ReportError('warning', "$ME $notonmain; refusing to refresh", 0);
	FreshPorts::Utilities::ReportError('warning', "$ME leave it to whatever returns it to main.  Do not pull or fetch.", 0);
	exit 1;
}

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

if ($debug eq 'y') {
	print "\$dryrun='$dryrun'\n";
	print "sql = $sql\n";
}

$sth = $dbh->prepare($sql);

my $refreshed = 0;
my $dryrunned = 0;
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
			foreach my $why (WhyVersionComesFromWhere($category_port)) {
				my $reason = "$ME $category_port: $why";

				print $reason . "\n";
				FreshPorts::Utilities::Report('info', $reason);
			}

			if ($dryrun eq 'y') {
				# everything above reads; save() and commit() are the only
				# things which write, so a dry run simply stops here
				$dbh->rollback();
				$dryrunned++;
			} else {
				$port->save($currentBranch);
				# commit each port on its own, so a failure part way through
				# does not throw away the ports already done
				$dbh->commit();
				$refreshed++;
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

my $tally = "$ME ends: $refreshed refreshed, $failed failed, $notfound not found";

if ($dryrun eq 'y') {
	$tally = "$ME ends: $dryrunned would be refreshed, $failed failed, $notfound not found (dry run, nothing written)";
}

print $tally . "\n";
FreshPorts::Utilities::Report('info', $tally);

$dbh->commit();
$dbh->disconnect();
