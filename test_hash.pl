#!/usr/local/bin/perl -w
#
# $Id: test_hash.pl,v 1.2 2001-12-22 04:30:42 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#
use strict;

my $hash = {};

$hash->{things}=1;
if ($hash->{things}) {
	print "things\n";
} else {
	print "nothing\n";
}
