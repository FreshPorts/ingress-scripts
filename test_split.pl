#!/usr/local/bin/perl -w
#
# $Id: test_split.pl,v 1.2 2001-12-22 04:30:43 dan Exp $
#
# Copyright (c) 2001-2026 Dan Langille
#

use strict;

my $category;
my $name;
my $extra;

my $partialpathname = "security/logcheck/things";

($category, $name, $extra) = split/\//,$partialpathname, 2;

print "$category\n";
print "$name\n";
print "$extra\n";
