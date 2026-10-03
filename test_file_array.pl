#!/usr/local/bin/perl -w
#
# $Id: test_file_array.pl,v 1.2 2001-12-22 04:30:42 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#
use strict;

my %Updates;
my @Files;

my ($action, $path, $revision);
my $value;

$Updates{FileAction}	= 'Modify';
$Updates{FilePath}		= 'ports/textproc/Dwordnet/Makefile';
$Updates{FileRevision}	= '1.4';

push @Files, [$Updates{FileAction}, $Updates{FilePath}, $Updates{FileRevision}];

foreach $value (@Files) {
	($action, $path, $revision) = @$value;
	print "$action, $path, $revision\n";
}
