#!/usr/local/bin/perl -w
#
# $Id: ExportXMLFromDB.pl,v 1.8 2002-03-11 00:15:24 dan Exp $
#
# Copyright (c) 2001 DVL Software
#
# Process incoming mail from cvs-all mailing list at freebsd.org
# and convert it to XML output according to the FreshPorts DTD.
#

use strict;
use DBI;
use IO;
use XML::Writer;

my $outputdir  = "./output";

&main;
exit;

#####
# Main Processing Routine
#####
sub main {
	my $limit	= 0;
	my $i		= 0;

	if (($#ARGV+1) == 1) {
        print "there is 1 argument\n";

        $limit = $ARGV[0];
		print "\$limit = $limit\n";
	}

	my $dbh = db_handle();

	my $change_log;

	my $sql = "select distinct change_log.* 
				from change_log, change_log_port, ports
			   where ports.status  = 'A'
			 	 and ports.id      = change_log_port.port_id
                 and change_log.id = change_log_port.change_log_id
and change_log.id = 24410
            order by change_log.id
			limit 1";

	if ($limit > 0) {
		$sql .= " limit $limit";
	}

	print "\$sql = '$sql'\n";
	my $sth = $dbh->prepare($sql);
	$sth->execute ||
		die "Could not execute SQL $sql ... maybe invalid?";

	while ($change_log = $sth->fetchrow_hashref) {
		$i++;
		if ($i % 100) {
			print <STDOUT>, ".";
		} else {
			print <STDOUT>, "$i";
		}
		# Get the data
		my ($Data_ref) = &GetData($change_log);

		my $outputfile = sprintf("$outputdir/output.%05d.xml", $change_log->{id});

		my $output = new IO::File(">$outputfile") || 
			die "failed to create output file";

		# Create the XML
		&WriteXML($Data_ref, $output);

		$output->close();

	}
	$dbh->disconnect();

	# Done!  Woo woo!
	exit;
}

sub db_handle {
	my $dbh;

	$dbh = DBI->connect('dbi:mysql:freshports','root','xyzzy');

	if (!$dbh) {
		die "could not connect to FreshPorts1\n";
	}

	return $dbh;
}

#####
# GetData - Generate and return the data structure
#####
sub GetData ($){
	my $change_log	= shift;
	my (@Data);

	my $Message_Subject;
	my $Log;

	$Message_Subject	= &GetMessage_Subject($change_log);
	$Log				= &GetLog($change_log);
	if ($Log eq '') {
		$Log = $Message_Subject;
	}

	@Data =	[	'UPDATES', [ { Version => '0.13' },
				'UPDATE', [ {},
					'DATE', [ &GetDate($change_log)
					],
					'TIME', [ &GetTime($change_log)
					],
					'OS', [ {
						Id	=> &GetOS_Id,
						Branch	=> &GetOS_Branch($change_log) }
					],
					'LOG', [ {},
						0,
						$Log
					],
					'PEOPLE', [ {},
						&GetPeople($change_log)
					],
					'MESSAGE', [ {
						Id	=> &GetMessage_Id($change_log),
						Subject	=> $Message_Subject },
						'DATE', [ &GetMessage_Date($change_log)
						],
						'TIME', [ &GetMessage_Time($change_log)
						],
						&GetMessage_To($change_log)
					],
					'FILES', [ {},
						&GetFiles($change_log)
					]
				]
			 ]
		];

	my ($PR) = &GetPR($change_log);
	if ($PR) {
		push @{$Data[0]->[1][2]}, 'PR', [ { Id => $PR } ];
	}

	return @Data;
}

#####
# WriteXML - Convert the data into XML and print
#####
sub WriteXML($;$) {
	my ($data_ref)	= shift;
	my ($output)	= shift;

	# Use XML::Writer to create the XML
	my ($writer) = new XML::Writer( DATA_INDENT => 4,
					DATA_MODE => 1, OUTPUT => $output );

	# use the right encoding so strings like Lyngbøl will work for XML::Parser when
	# it comes time to read this stuff back in...
	# the default is: UTF-8.  We want ISO-8859-1.

	# Add the main XML tag
	$writer->xmlDecl("ISO-8859-1");

	# Add the XML Document Type
	$writer->doctype('UPDATES','-//Freshports//DTD Freshports 2.0//EN', 'https://www.freshports.org/docs/fp-updates.dtd');

	# Convert the data into XML
	&DataToXML($writer, $data_ref); 

	# No more XML
	$writer->end;
}

#####
# DataToXML - Convert the data into XML; tends to call itself
#####
sub DataToXML {
	my ($writer) = shift;
	my ($data_ref) = shift;

	my ($count) = $#{$data_ref};
	for (my ($i) = 0; $i < $count; $i += 2) {
		my ($element_name)		= shift @{$data_ref};
		my ($element_content)		= shift @{$data_ref};

		if ($element_name eq '0') {
			$writer->characters($element_content);
		} else {
			my ($element_attributes)	= shift @{$element_content};

			$writer->startTag($element_name, %$element_attributes);
			&DataToXML($writer, $element_content);
			$writer->endTag($element_name);
		}
	}
}
####################################################################
##### Functions to actually retrieve the data from the message #####
####################################################################

sub GetPR {
	my ($message) = @_;
	my ($PR);

	return $PR;
}

sub GetPeople {
    my ($tmp)       = shift;
    my %message     = %{$tmp};
	my (@people);

	#
	# this is where we should be finding the committer
	#
	my $committer =   $message{committer};
	push @people, 'UPDATER',   [ { Handle =>  $committer } ];
	push @people, 'SUBMITTER', [ { Handle => 'unknown' } ];

	return @people;
}

sub GetObtainedFrom {
	my ($message) = @_;
	my ($ObtainedFrom);

	return $ObtainedFrom;
}

sub GetApprover {
	my ($message) = @_;
	my ($Approver);

	return $Approver;
}

sub GetReviewer { 
	my ($message) = @_;
	my ($Reviewer);

	return $Reviewer;
}

sub GetSubmitter {  
	my ($message) = @_;
	my ($Submitter);
        
	return $Submitter;
}

sub GetFiles {
	my ($tmp)		= shift;
	my %message		= %{$tmp};

	my $files;
	my @files;
	my $changes1	= "+0";
	my $changes2	= "+0";
	my $revision	= 'unknown';

	my $dbh = db_handle();

	my $id = $message{id};

	my $sql = "select ports.name as port, categories.name as category, 
					  change_type, details 
				from change_log_details, ports, categories, change_log_port
				where change_log_port.change_log_id         = $id
                  and change_log_port.port_id               = ports.id 
                  and ports.primary_category_id             = categories.id
                  and change_log_details.change_log_port_id = change_log_port.id
             order by categories.name, ports.name, details";

	my $sth = $dbh->prepare($sql);
	$sth->execute ||
		die "Could not execute SQL $sql ... maybe invalid?";

	while ($files = $sth->fetchrow_hashref) {

		my $path = "ports/" . $files->{category} . "/" . $files->{port} . "/" .
					$files->{details};
		my $action = $files->{change_type};
		if ($action eq 'M') {
			$action = 'Modify';
		} else {
			if ($action eq 'R') {
				$action = 'Remove';
			} else {
				if ($action eq 'A') {
					$action = 'Add';
				} else {
					if ($action eq 'I') {
						# we have a special case.  In FP1, we dealt with early imports
						# in a very not nice way.  We didn't record anything in the details field.
						# so we will just assume the Makefile here.
						$action = 'Add';
						$path = "ports/" . $files->{category} . "/" . $files->{port} . "/Makefile";
					} else {
						$action = 'unknown action';
					}
				}
			}
		}

		push @files, 'FILE', [ { Action => $action, Revision => $revision, 
								Changes => "$changes1 $changes2", 
								Path => $path } ]; 
	}

	return @files;
}

sub GetOS_Id {
	my ($message) = shift;

	return 'FreeBSD';
}

sub GetOS_Branch {
	my ($message) = @_;

	return 'HEAD';
}

sub GetLog {
	my ($tmp)		= shift;
	my %change_log	= %{$tmp};
	my ($log)		= 'nil';

	if (defined($change_log{update_description})) {
		$log = $change_log{update_description};
	}
	return $log;
}

sub GetDate {
	my ($message) = shift;
	return GetMessage_Date($message);
}
 
sub GetTime($) {
	my $message = shift;
	return GetMessage_Time($message);
}

sub GetMessage_Date($) {
	my ($tmp)		= shift;
	my %message		= %{$tmp};
	my ($date, $year, $month, $day);
	my (%months) = ( 'Jan' => 1, 'Feb' => 2, 'Mar' => 3, 'Apr' => 4, 
                     'May' => 5, 'Jun' => 6, 'Jul' => 7, 'Aug' => 8, 
					 'Sep' => 9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12 ); 

	$date = $message{commit_date};

	$year	= substr($date, 0, 4);
	$month	= substr($date, 5, 2);
	$day	= substr($date, 8, 2);

	$date = {	Year	=> $year,
				Month	=> int($month),
				Day		=> int($day) };

	return $date;
}
                                          
sub GetMessage_Time($) {
	my ($tmp)		= shift;
	my %message		= %{$tmp};
	my ($time, $hour, $minute, $second, $timezone);

	$time = $message{commit_date};

	$hour		= substr($time, 11, 2);
	$minute		= substr($time, 14, 2);
	$second		= substr($time, 17, 2);
	$timezone	= 'PST';

	$time = {	Hour		=> int($hour),
				Minute		=> int($minute),
				Second		=> int($second),
				Timezone	=> $timezone };

	return $time;
}

sub GetMessage_Id {
	my ($tmp)		= shift;
	my %message		= %{$tmp};
	my $Id;

	# FP1 messages don't have message ids.
	# so use fp1.id@freshports.org instead

	$Id = "fp1.$message{id}\@freshports.org";

	return $Id;
}

sub GetMessage_To {
	my ($message) = shift;

	my (@to) = ();
	push @to, 'TO';
	push @to, [{ 'Email' => 'cvs-all@FreeBSD.org' } ];
	push @to, 'TO';
	push @to, [{ 'Email' => 'cvs-committers@FreeBSD.org' } ];

	return @to;
}

sub GetMessage_Subject($) {
	my ($change_log) = shift;

	return "nil";
}
