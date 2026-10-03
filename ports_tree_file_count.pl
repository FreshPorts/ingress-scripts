#!/usr/local/bin/perl -w
#
# $Id: ports_tree_file_count.pl,v 1.2 2007-10-11 18:15:33 dan Exp $
#
# Copyright (c) 1999-2026 Dan Langille
#

use strict;
use FreshPorts::config;
use FreshPorts::constants;
use FreshPorts::system_status;

#
# see if the system is online.
# If not, exit.
#
my $SystemStatus = FreshPorts::SystemStatus->new();
if (!$SystemStatus->Online()) {
	exit 0;
}

# this is hardcoded to HEAD for now
my $Command = "/usr/bin/find $FreshPorts::Config::JailBaseDir/$FreshPorts::Config::PortsDir -type f | /usr/bin/wc -l > $FreshPorts::Config::PortsTreeCount";

# print $Command;

`$Command`;
