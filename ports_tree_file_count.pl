#!/usr/local/bin/perl -w
#
# $Id: ports_tree_file_count.pl,v 1.2 2007-10-11 18:15:33 dan Exp $
#
# Copyright (c) 1999-2007 DVL Software
#

use strict;
use FreshPorts::constants;
use FreshPorts::config;

# this is hardcoded to HEAD for now
my $Command = "/usr/bin/find $FreshPorts::Config::RepoDir/$FreshPorts::Constants::Repo_Ports | /usr/bin/wc -l > $FreshPorts::Config::PortsTreeCount";

# print $Command;

`$Command`;
