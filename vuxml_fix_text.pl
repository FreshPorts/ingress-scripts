#!/usr/local/bin/perl -w
#
# Copyright (c) 2026 Dan Langille
#
# Rewrite vuxml.topic and vuxml.description from vuln.xml, and nothing else.
#
# process_vuxml.pl replaces a changed vuln by deleting it and inserting it
# again, then marks every affected commit again.  For all ~6700 vulns that
# takes most of a day.  When only the way the text is parsed has changed
# (e.g. the UTF-8 fix in ingress-modules 306fbfe), the packages, ranges,
# references and commit marks are already right, so update the text in
# place, keeping vuxml.id and everything which refers to it.
#
# The checksum is set too, so the next process_vuxml.pl run does not
# select every vuln again.
#
# A vuln whose package names, ranges or references contain non-ASCII
# text is not updated: the parse encoding could have changed those too.
# They are listed at the end; process them with process_vuxml.pl.
#
# Usage: vuxml_fix_text.pl --filename=<flattened vuln.xml> [--dryrun] [--showvids]
#
# Use vuxml_fix_text.sh, which flattens vuln.xml and holds VUXMLMUTEX.
#

use strict;
use warnings;
use XML::DOM::XPath;
use Encode;
use Digest::SHA qw(sha256_hex);
use IO::String;
use Getopt::Long;

use FreshPorts::database;
use FreshPorts::vuxml_parsing;

# parse each vuln, but leave the database alone: process_vuxml.pl writes
# from update_database(), at the end of each </vuln>
package FreshPorts::vuxml_parsing_text_only;
our @ISA = ('FreshPorts::vuxml_parsing');
sub update_database { return shift; }

package main;

use constant CommitEvery => 500;

my $filename;
my $dryrun;
my $showvids;

binmode STDOUT, ":encoding(UTF-8)";

# XML::Parser reads into an undefined buffer, which IO::String warns about
# once per vuln.  It is harmless; let every other warning through.
$SIG{__WARN__} = sub { warn @_ unless $_[0] =~ m{IO/String\.pm line \d+} };

my $usage = "usage: $0 --filename=<flattened vuln.xml> [--dryrun] [--showvids]\n";

GetOptions('filename=s' => \$filename,
           'dryrun!'    => \$dryrun,
           'showvids!'  => \$showvids) || die($usage);

die($usage) unless defined $filename;

# without the UTF-8 fix (ingress-modules 306fbfe) this would store the old, garbled text again
FreshPorts::vuxml_parsing->can('escape_html') || die("FATAL: $0 needs FreshPorts::vuxml_parsing from ingress-modules 306fbfe or later\n");

print "vuxml_fix_text.pl starts\n";
print "this is a dry run: nothing will be committed\n" if $dryrun;

my $start = time;

my $dbh = FreshPorts::Database::GetDBHandle() || die("FATAL: $0 could not get a db handle");

# Only rows whose topic, description or checksum differ are written.  The
# comparison is left to the database rather than done here: fetching each
# row to compare would cost a query per vuln anyway, and comparing in Perl
# means getting the encoding right twice (what DBD::Pg sends vs what it
# returns).  IS DISTINCT FROM compares the values as stored, and, unlike <>,
# treats NULL as a value, so a NULL checksum is replaced too.  An unchanged
# row is not rewritten, so it leaves no dead tuple for vacuum.
my $sth = $dbh->prepare('
UPDATE vuxml
   SET topic       = $1,
       description = $2,
       checksum    = $3
 WHERE vid = $4
   AND (topic       IS DISTINCT FROM $1
     OR description IS DISTINCT FROM $2
     OR checksum    IS DISTINCT FROM $3)');

my $parser = new XML::DOM::Parser;
my $doc    = $parser->parsefile($filename);

print "vuln.xml has been read\n";

my $fh = IO::String->new();

my $NumVulns     = 0;
my $NumCancelled = 0;
my $NumUpdated   = 0;
my @NonASCII;

for my $node ($doc->findnodes('/vuxml/vuln')) {
	my $vid = $node->getAttributeNode('vid')->getValue();

	# cancelled vulns are not in the vuxml table
	if ($node->getElementsByTagName('cancelled')->getLength() > 0) {
		$NumCancelled++;
		next;
	}

	$NumVulns++;

	# the same checksum process_vuxml.pl stores
	my $nodeString = $node->toString();
	my $csum       = sha256_hex(Encode::encode_utf8($nodeString));

	# the parser reads bytes, so give it the node as UTF-8
	$fh->open(Encode::encode_utf8($nodeString)) || die("FATAL: $0 could not \$fh->open");

	my $p = FreshPorts::vuxml_parsing_text_only->new(Stream => $fh);
	$p->parse_xml($csum);
	$fh->close;

	# everything stored in vuxml_affected, vuxml_names, vuxml_ranges and
	# vuxml_references.  ASCII parses the same in any encoding.
	my @others;
	for my $package ($p->packages()) {
		push @others, $package->name(), $package->category(), $package->architecture();
		push @others, grep { defined } @$_ for $package->range();
	}
	push @others, @$_ for $p->references();

	if (grep { /[^\x00-\x7F]/ } @others) {
		push @NonASCII, $vid;
		next;
	}

	my $rows = $sth->execute($p->topic(), $p->description(), $csum, $vid);
	if (!defined $rows) {
		$dbh->rollback();
		die("FATAL: $0 could not update $vid: " . $dbh->errstr . "\n");
	}

	if ($rows > 0) {
		$NumUpdated++;
		print "updated: $vid\n" if $showvids;
		if ($NumUpdated % CommitEvery == 0) {
			$dryrun ? $dbh->rollback() : $dbh->commit();
			print "$NumUpdated updated after $NumVulns vulns, " . (time - $start) . " seconds\n";
			STDOUT->flush();
		}
	}
}

$doc->dispose;

$dryrun ? $dbh->rollback() : $dbh->commit();
$dbh->disconnect();

print "vulns read:      $NumVulns (plus $NumCancelled cancelled)\n";
print "vulns updated:   $NumUpdated" . ($dryrun ? ' (dry run: rolled back)' : '') . "\n";
print "vulns skipped:   " . scalar(@NonASCII) . " (non-ASCII outside topic and description)\n";
print "    $_\n" for @NonASCII;
print "Total time:      " . (time - $start) . " seconds\n";

print "vuxml_fix_text.pl finishes\n";
