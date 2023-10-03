#!/usr/local/bin/perl -w
#
# $Id: test_grep.pl,v 1.2 2001-12-22 04:30:42 dan Exp $
#
# Copyright (c) 2001 DVL Software
#

use strict;

print `grep zope-zwiki-0.9.4.tgz packages.exists`;

print "result = " . ($? >> 8) . "\n";
