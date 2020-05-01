#!/bin/sh
#
# $Id: cache-refresh.sh,v 1.2 2006-12-17 12:03:59 dan Exp $
#
# Copyright (c) 2004 DVL Software Limited
#

LOGGERTAG="$0"

set -e

# invoke this to get the right value for $LOGGER

. config.sh

$LOGGER -t ${LOGGERTAG} starts

# I'm hardcoding this path here.
# This delete is too easy to mess up with a configuration file setting

DELDIR=/var/db/freshports/cache/packages

mkdir $DELDIR/DELETEME
mv $DELDIR/* DELETEME
rm -rf $DELDIR DELETEME

${LOGGER} -t ${LOGGERTAG} finishes
