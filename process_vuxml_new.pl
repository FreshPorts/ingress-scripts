#!/usr/local/bin/perl -w
#
# $Id: process_vuxml.pl,v 1.6 2013-01-16 15:37:57 dan Exp $
#
# Copyright (c) 2001-2012 DVL Software
#
# much of this file is based on contributions from Matthew Seamon
#

# @{#} $Id: process_vuxml.pl,v 1.6 2013-01-16 15:37:57 dan Exp $
#
# Split up the vuln.xml file into sections for individual
# vulnerabilities.  Save into files using the vid guid field as name.
# Calculate SHA256 checksum for the XML snippet and write out to an
# index file.

#use 5.10.1;
use strict;
use warnings;
use XML::DOM::XPath;
use Encode;
use Digest::SHA qw(sha256_hex);
use autodie qw(:default);
use IO::String;
use Getopt::Long;
use File::Temp ();

use FreshPorts::database;
use FreshPorts::vuxml;
use FreshPorts::vuxml_parsing;
use FreshPorts::vuxml_mark_commits;

my $PSQL = "/usr/local/bin/psql";

my $filename;
my $dryrun;
my $showchecksums;
my $printnodes;
my $showreasons;

my $nodeString;
my $NumUpdates = 0;

# From https://perldoc.perl.org/perlunifaq.html#What-is-a-%22wide-character%22%3f
# to handle: Wide character in print at /usr/local/lib/perl5/site_perl/FreshPorts/vuxml_parsing.pm line 234, <> chunk 1.\n

binmode STDOUT, ":encoding(UTF-8)";

#use feature qw(switch);

print 'process_vuxml.pl starts' . "\n";


# Reads vuln.xml on stdin * NOT ANY MORE
GetOptions ('filename:s'     => \$filename,
            'dryrun!'        => \$dryrun,
            'showchecksums!' => \$showchecksums,
            'printnodes!'    => \$printnodes,
            'showreasons!'   => \$showreasons);

if ($dryrun) {
  print "this is a dry run\n";
}

if ($showchecksums) {
  print "checksums will be displayed\n";
}

if ($printnodes) {
  print "nodes will be displayed\n";
}

if ($showreasons) {
  print "reasons will be displayed\n";
}

my $start = time;

print '(there is usually a delay before further output)' . "\n";

MAIN:
{
    my %vulns;
    my @vulns;

    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parsefile ($filename);
    
    print "There, the parsefile has completed\n";

    # UNLINK = false is for debugging purposes
    my $fh_vid    = File::Temp->new(UNLINK => 0, PERMS => 0644);
    my $fname_vid = $fh_vid->filename;
    
    my $dbh;
    $dbh = FreshPorts::Database::GetDBHandle();
    if ($dbh->{Active}) {
        my $fh = IO::String->new();
#        my $vuxml = FreshPorts::vuxml->new( $dbh );


        print "calculating the sha256 for each vuln\n";
        eval {
            for my $node ($doc->findnodes('/vuxml/vuln'))
            {
                if ($dryrun && !$showchecksums) {
                    print '.';
                }
                my $vid  = $node->getAttributeNode('vid')->getValue();
                my $csum = sha256_hex(Encode::encode_utf8($node->toString));

                print $fh_vid "$vid\t$csum\n";
                #print         "$vid\t$csum\n";
            } # for my $node
        }; # eval

        print "all sha256 saved for each vuln\n";

        $fh_vid->close();

        # added after seeing it at https://metacpan.org/dist/XML-DOM/view/lib/XML/DOM/Parser.pod
        $doc->dispose;

        print 'finished with eval()' . "\n";

        # if something went wrong in the eval, abort and don't do a commit
        if ($@) {
            print "We've got a problem.";
            print "$0: $@\n";
            FreshPorts::CommitterOptIn::RecordErrorDetails("error processing vuxml", $0);
            die "$0: $@\n";
        }

        my $file_path = "$fname_vid";
        my $table_name = "vuxml_import";
        my $copy_sql = "COPY $table_name FROM '$file_path' WITH (FORMAT TEXT, DELIMITER '\t', HEADER false)";
        my $truncate_sql = "TRUNCATE vuxml_import";

        # our goal is this:
        # echo "\\\copy vuxml_import from '/tmp/vnhvGB2yN0' WITH (FORMAT TEXT, HEADER false);" | psql "sslmode=require host=pg01.int.unixathome.org user=commits_dvl dbname=freshports.dvl"

        # sslcertmode=disable avoids could not open certificate file “/root/.postgresql/postgresql.crt”: Permission denied
        my $psql_command = "$PSQL \"sslmode=$FreshPorts::Config::ssl_mode host=$FreshPorts::Config::host user=$FreshPorts::Config::user dbname=$FreshPorts::Config::dbname sslcertmode=disable\"";
        my $copy_command = "\\copy vuxml_import from '$file_path' WITH (FORMAT TEXT, HEADER false);";


        print "\$copy_command='$copy_command\n";
        print "\$psql_command='$psql_command\n";
        eval {
            $dbh->do($truncate_sql);
            print "committing truncate\n";
            $dbh->commit();


            print "echo \"$copy_command\" | $psql_command";
            print "\n";

            system("echo \"$copy_command\" | $psql_command");
            print "copy command has finished\n";
        };
        if ($@) {
            warn "Error during COPY: $@";
            $dbh->rollback(); # Rollback on error
        }


        $dbh->disconnect();
    } # if ($dbh->{Active}

    undef $dbh;

} # MAIN

my $end = time();

print "Total time: " . ($end - $start) . " seconds\n";

print "Number of updates: $NumUpdates\n";

if ($dryrun) {
  print "this was a dry run\n";
}

#
# That's All Folks!
#

print 'process_vuxml.pl finishes' . "\n";
