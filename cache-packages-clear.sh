#!/bin/sh
#
# $Id: cache-refresh.sh,v 1.2 2006-12-17 12:03:59 dan Exp $
#
# Copyright (c) 2004 DVL Software Limited
#

LOGGERTAG="$0"

# invoke this to get the right value for $LOGGER
if [ ! -f config.sh ]
then
	exit 1
fi

. config.sh

$LOGGER -t ${LOGGERTAG} starts

# I'm hardcoding this path here.
# This delete is too easy to mess up with a configuration file

DELDIR=/var/db/freshports/cache/packages/

if [ -d $DELDIR ]
then
	cd $DELDIR
	if [ $? -ne 0 ]
	then
		 ${LOGGER} -t ${LOGGERTAG} FATAL - unable to cd into $DELDIR
	fi

	mkdir DELETEME && mv ./* DELETEME && rm -rf DELETEME
	if [ $? -ne 0 ]
	then
	  ${LOGGER} -t ${LOGGERTAG} FATAL - unable to clear cache at $DELDIR
	fi
else

	${LOGGER} -t ${LOGGERTAG} FATAL - could not cd into $DELDIR

fi

${LOGGER} -t ${LOGGERTAG} finishes
