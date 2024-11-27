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

use FreshPorts::database;
use FreshPorts::vuxml;
use FreshPorts::vuxml_parsing;
use FreshPorts::vuxml_mark_commits;

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
    
    my $dbh;
    $dbh = FreshPorts::Database::GetDBHandle();
    if ($dbh->{Active}) {
        my $fh = IO::String->new();
        my $vuxml = FreshPorts::vuxml->new( $dbh );
          
        eval {
            for my $node ($doc->findnodes('/vuxml/vuln'))
            {
                if ($dryrun && !$showchecksums) {
                    print '.';
                }
                my $vid  = $node->getAttributeNode('vid')->getValue();
                my $csum = sha256_hex(Encode::encode_utf8($node->toString));
                
                # fetch the checksum from the database
                my $checksum = $vuxml->FetchChecksumByVID($vid);

                my $updateRequired = 1;
                if (defined($checksum)) {

                    if ($csum eq $checksum) {
                        # comment out the next line to always update
                        $updateRequired = 0;
                    }

                    if ($showchecksums) {
                        print "vuln check: $vid = '$csum'";
                        if ($updateRequired) {
                            print " '$checksum'";
                        }
                        print "\n";
                    }
                    if ($updateRequired && $showreasons) {
                        print "$vid will be updated because of checksum differences\n";
                    }
                } else {
                    if ($showchecksums) {
                        print "vuln check: $vid = '$csum' not found\n";
                    }
                    if ($showreasons) {
                        print "$vid will be updated because is it not in the database\n";
                    }
                }
                
                if ($updateRequired) {
                    $NumUpdates++; 
                }
                
                if ($updateRequired && $dryrun) {
                     # add after the .
                     if (!$showchecksums) {
                         print "\n";
                     }
                     print "\n$vid would have been updated because of checksum\n\n";
                }

                if ($updateRequired) {
                    $nodeString = $node->toString();
                    if ($printnodes) {
                        print $nodeString . "\n";
                    }
                    if ($fh->open($nodeString)) {
                        if (!$dryrun) {
                            my $p = FreshPorts::vuxml_parsing->new(Stream        => $fh,
                                                                   DBHandle      => $dbh,
                                                                   UpdateInPlace => 1);

                            # always pass in the checksum from our calculation
                            $p->parse_xml($csum);

                            if ($p->database_updated()) {
                                print "yes, the database was updated for $vid\n";
                            } else {
                                print "no, the database was NOT updated for $vid\n";
                                next;
                            }

                            $fh->close;

                            # process $vulns{$v} via vuxml_processing

                            print 'invoking vuxml_mark_commits with ' . $vid . "\n";
                            my $CommitMarker = FreshPorts::vuxml_mark_commits->new(DBHandle => $dbh,
                                                                           vid      => $vid);
                            print 'invoking ProcessEachRangeRecord'. "\n";
                            my $i = $CommitMarker->ProcessEachRangeRecord();

                            print 'invoking ClearCachedEntries' . "\n";
                            $CommitMarker->ClearCachedEntries($vid);
                    
                            # for debugging
                            #last;
                        } # if (!$dryrun)                    
                    } else {
                        die "fh->open failed";
                    }# if ($fh->open
                } # if ($updateRequired)
            } # for my $node
        }; # eval

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

        print "committing\n";
        $dbh->commit();

        $dbh->disconnect();
    } # if ($dbh->{Active}
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
