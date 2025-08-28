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

use strict;
use warnings;
use XML::DOM::XPath;
use Encode;
use Digest::SHA qw(sha256_hex);
use autodie qw(:default);
use IO::String;
use Getopt::Long;
use File::Temp();

# for debugging
use Data::Dumper;

use FreshPorts::database;
use FreshPorts::vuxml;
use FreshPorts::vuxml_parsing;
use FreshPorts::vuxml_mark_commits;

# minimum number of imports we should expect. This attempts to catch
# a failed import of the vuxml_import table.
#
use constant ExpectedCopy    => 5900;
use constant ExpectedDelete  => 10;
use constant ExpectedUpdates => 100;

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

sub populate_vuxml_import($;$)
{
    my $dbh = shift;
    my $doc = shift;

    # UNLINK = false is for debugging purposes
    # create a file, looking like that, in the tmp dir, with those permissions.
    my $fh_vid    = File::Temp->new(TEMPLATE => 'freshports_vuxml_processing_XXXXX', TMPDIR => 1, UNLINK => 0, PERMS => 0644);
    my $fname_vid = $fh_vid->filename;
    
    my $fh = IO::String->new();

    print "calculating the sha256 for each vuln\n";
    eval {
        my $i = 0;
        print "doing the findnodes() thing\n";
        for my $node ($doc->findnodes('/vuxml/vuln'))
        {
            if ($i == 0) {
                print "findnodes() has finished, iteration has started\n";
            }
            # this magic from https://stackoverflow.com/questions/22791304/progress-line-in-perl#22791628
            $i++;
            if ($i % 10 == 0) {
                # Every 100 items, print a dot.
                print ".";
                STDOUT->flush();
            }

            if ($dryrun && !$showchecksums) {
                print '.';
            }
            my $vid = $node->getAttributeNode('vid')->getValue();
            my $cancelled = $node->getElementsByTagName('cancelled');
            if ($cancelled->getLength() > 0) {
                print "\n$vid - cancelled: skipping that one for import\n";
                next;
            }

            my $csum = sha256_hex(Encode::encode_utf8($node->toString));

            # write vid and checksum to the file
            print $fh_vid "$vid\t$csum\n";
        } # for my $node
    }; # eval

    print "all sha256 saved for each vuln\n";

    $fh_vid->close();

    print 'finished with checksum eval()' . "\n";

    # if something went wrong in the eval, abort and don't do a commit
    if ($@) {
        print "We've got a problem.";
        print "$0: $@\n";
        FreshPorts::CommitterOptIn::RecordErrorDetails("error processing vuxml", $0);
        die "$0: $@\n";
    }

    my $file_path    = "$fname_vid";
    my $table_name   = "vuxml_import";
    my $truncate_sql = "TRUNCATE vuxml_import";

    # our goal is this:
    # echo "\\\copy vuxml_import from '/tmp/vnhvGB2yN0' WITH (FORMAT TEXT, HEADER false);" | $PSQL "sslmode=require host=pg01.int.unixathome.org user=commits_dvl dbname=freshports.dvl"

    # sslcertmode=disable avoids could not open certificate file “/root/.postgresql/postgresql.crt”: Permission denied
    my $psql_command = "$PSQL \"sslmode=$FreshPorts::Config::ssl_mode host=$FreshPorts::Config::host user=$FreshPorts::Config::user dbname=$FreshPorts::Config::dbname sslcertmode=disable\"";
    my $copy_command = "\\copy vuxml_import from '$file_path' WITH (FORMAT TEXT, HEADER false);";

    print "\$copy_command='$copy_command'\n";
    print "\$psql_command='$psql_command'\n";

    # save it to the database
    eval {
        $dbh->do($truncate_sql);
        print "committing truncate\n";
        # we commit this here because the psql import which follows will deadlock.
        $dbh->commit();


        print "echo \"$copy_command\" | $psql_command";
        print "\n";

        # need to check how many rows. Should be at least 5900

        # use qx, similar to `backticks` - use chomp to remove the trailing whitespace
        #chomp(my $output = qx/echo "$copy_command;" | $psql_command/);
        chomp(my $output = qx|/usr/local/libexec/freshports/process_vuxml_import_temp_file.py --ifile=$file_path|);
        print "copy command has finished\n";
        print "\$output is '$output'\n";

        # grab the number of rows imported: https://stackoverflow.com/questions/3574906/how-to-extract-a-number-from-a-string-in-perl#3574959
        my ($count) = $output =~ /(\d+)/;

        print "Imported $count items\n";

        if ($count < ExpectedCopy) {
            $dbh->rollback(); # Rollback on error
            # we do not return from this call
            FreshPorts::Utilities::ReportError('err', "FATAL: we imported $count items, which is less than our expected minimum value of " . ExpectedCopy . "\n", 1);
            # but just in case we do
            die("bad number of vuxml_import");
        }
    };
    if ($@) {
        warn "Error during COPY: $@";
        $dbh->rollback(); # Rollback on error
    }
} # MAIN

sub remove_deleted_vids($)
{
    my $dbh = shift;
    my @row;
    my $RowsDeleted;

    # returns the number of deleted rows. If more than 1000, rollback and abort
    #
    my $DeleteMissingVuxml = "select DeleteMissingVuxml()";
    # invoke the stored procedure: DeleteMissingVuxml()
    eval {
        my $sth = $dbh->prepare($DeleteMissingVuxml);
        $sth->execute || FreshPorts::Utilities::ReportError('warning', "Could not execute SQL statement\n--$DeleteMissingVuxml--\n... maybe invalid?", 1);
        print "deleting missing vuxml\n";
        @row = $sth->fetchrow_array();
        $RowsDeleted = $row[0];
        
        if ($RowsDeleted > ExpectedDelete) {
            $dbh->rollback(); # Rollback on error
            # we do not return from this call
            FreshPorts::Utilities::ReportError('err', "FATAL: we were deleting way too many rows from vuxml: $RowsDeleted items, which is more than our expected minimum value of " . ExpectedDelete . "\n", 1);
            # but just in case we do
            die("bad number of vuxml deleted");
        }

        # We commit because later we will be importing via psql and we don't want those two to deadlock
        $dbh->commit();

        print "vuln not present in xml files have been deleted from the database.\n";
    };
    if ($@) {
        warn "Error during delete: $@";
        $dbh->rollback(); # Rollback on error
    }
}


sub get_list_of_modified_and_new_vids($)
{
    # invoke the stored procedure: GetListOfVulnsForUpdate() which returns a list of new vulns
    # and vulns with new checksums
    my $dbh = shift;

    my %ListOfVIDs;
    my @row;

    my $VidsToUpdate = "select * from GetListOfVulnsForUpdate()";
    # invoke the stored procedure: GetListOfVulnsForUpdate()
    eval {
        my $sth = $dbh->prepare($VidsToUpdate);
        $sth->execute || FreshPorts::Utilities::ReportError('warning', "Could not execute SQL statement\n--$VidsToUpdate--\n... maybe invalid?", 1);
        print "getting list of vulns to update\n";

        while (@row = $sth->fetchrow_array()) {
            print "found vid: $row[0]\n";

            $ListOfVIDs{$row[0]} = $row[0];
        }

        $sth->finish();
        # let's let the calling process do this
#        $dbh->commit();

        print "list of vulns to update has been obtained\n";
    };
    if ($@) {
        warn "Error during list of vulns: $@";
        $dbh->rollback(); # Rollback on error
    }

    return %ListOfVIDs;
}

sub update_modified_vids($;$;$)
# update_modified_vids($dbh, $doc, \%VIDsToUpdate);
{
    # given a hash/array of vids, go through the vuln.xml files and
    # save each of them to the database.
    my $dbh     = shift;
    my $doc     = shift;
    my $VIDsRef = shift;

#    my $fh;
    my %VIDsToUpdate = %{$VIDsRef};
    my %ProcessedVIDs;
    my $nodeString;

    # this code based on the existing process_vuxml.pl script
    my $fh = IO::String->new();

    for my $node ($doc->findnodes('/vuxml/vuln')) {
        my $vid = $node->getAttributeNode('vid')->getValue();
#        print "found vid: $vid\n";
        my $cancelled = $node->getElementsByTagName('cancelled');
        if ($cancelled->getLength() > 0) {
            print "cancelled is $vid - skipping that one again\n";
            next;
        }

        # if this vid is to be updated
        if ($VIDsToUpdate{$vid}) {
            print "found vid to update: $vid\n";
            # Keep track of what we have processed.
            # We use this to be sure we've processed everything.
            $ProcessedVIDs{$vid} = $vid;

            # Yes, we already calculated this the first time around
            # but we aren't storing it. Yet.
#            my $nodeString = $node->toString();

#            my $csum = sha256_hex(Encode::encode_utf8($nodeString));
            my $csum = sha256_hex(Encode::encode_utf8($node->toString));



#           my $csum = sha256_hex(Encode::encode_utf8($node->toString));

            $nodeString = $node->toString();

            print "This is that node:\n$nodeString\n";
            print "with csum=$csum\n";

            $fh->open($nodeString) || die("FATAL: $0 could not \$fh->open" );

            print "Getting a new vuxml_parsing\n";
            my $p = FreshPorts::vuxml_parsing->new(Stream        => $fh,
                                                   DBHandle      => $dbh,
                                                   UpdateInPlace => 1);

            print "parsing the xml and setting \$csum\n";
            # always pass in the checksum from our calculation
            $p->parse_xml($csum);

            if ($p->database_updated()) {
                print "yes, the database was updated for $vid\n";
                $NumUpdates++;
            } else {
                print "no, the database was NOT updated for $vid\n";
                next;
            }

            $fh->close;

            print 'invoking vuxml_mark_commits with ' . $vid . "\n";
            my $CommitMarker = FreshPorts::vuxml_mark_commits->new(DBHandle => $dbh,
                                                                   vid      => $vid);

            print 'invoking ProcessEachRangeRecord'. "\n";
            my $i = $CommitMarker->ProcessEachRangeRecord();

            print 'invoking ClearCachedEntries' . "\n";
            $CommitMarker->ClearCachedEntries($vid);

#            # putting this in here while debugging
#            last;
        }
    }

    print "reconciling processed against our list\n";
    # delete the ones we processed from the list of what we were looking for
    foreach my $key (keys %ProcessedVIDs) {
        delete $VIDsToUpdate{$key};
    }

    print "Checking to see if we missed anything.\n";
    # what do we have left?
    if (%VIDsToUpdate) {
        foreach my $key (keys %VIDsToUpdate) {
            print "Was unable to locate $key within the vuln.xml files.\n";
        }
        print "FATAL: we did not find everything we expected.\n";
    } else {
        print "We found and updated everything we expected.\n";
    }

}


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

my $dbh = FreshPorts::Database::GetDBHandle() || die("FATAL: $0 could not get a db handle" );

my $parser = new XML::DOM::Parser;
my $doc = $parser->parsefile ($filename);

print "There, the parsefile has completed\n";

# save the incoming vuln.xml file to a staging database table
populate_vuxml_import($dbh, $doc);

#die("We are stopping here while debugging this code\n");

remove_deleted_vids($dbh);

#
# NOTE inserts and updates are handled the same way
# delete existing vid (if any)
# insert
#
# Instead, we should collect new and modified together and do one traversal of the vuln.xlm document
#

my %VIDsToUpdate = get_list_of_modified_and_new_vids($dbh);

my $NumberOfUpdates = keys %VIDsToUpdate;

print "We have $NumberOfUpdates vuxml entries to add/update\n";

if ($NumberOfUpdates > ExpectedUpdates) {
    $dbh->rollback(); # Rollback on error
    # we do not return from this call
#    FreshPorts::Utilities::ReportError('err', "FATAL: we are about to update $NumberOfUpdates items, which is less than our expected minimum value of " . ExpectedUpdates . "\n", 1);
#    # but just in case we do
#    die("bad number of vuxml updates");
}


print "invoking update_modified_vids()\n";
if (%VIDsToUpdate) {
    update_modified_vids($dbh, $doc, \%VIDsToUpdate);
} else {
    print "Nothing to update\n";
}

# added after seeing it at https://metacpan.org/dist/XML-DOM/view/lib/XML/DOM/Parser.pod
$doc->dispose;

my $end = time();

print "Total time: " . ($end - $start) . " seconds\n";

print "Number of updates: $NumUpdates\n";

if ($dryrun) {
  print "this was a dry run\n";
}

print "committing\n";
$dbh->commit();

$dbh->disconnect();

undef $dbh;

#
# That's All Folks!
#

print 'process_vuxml.pl finishes' . "\n";
