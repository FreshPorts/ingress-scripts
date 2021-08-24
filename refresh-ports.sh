#!/bin/sh
# $Id$
#
# Copyright (c) 2003-2021 DVL Software Limited
#
# Check to see if the switch is set, and if so, process the contents of the
# ports_to_refresh table.
#

if [ ! -f config.sh ]
then
	echo "config.sh not found by process_moved.sh..."
	exit 1
fi

. config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

LOGGERTAG="$0"

${LOGGER} -t ${LOGGERTAG} "starting"

if [ "${PORTSTOREFRESHFLAG}x" = 'x' ]
then
	${LOGGER} -t ${LOGGERTAG} "please set PORTSTOREFRESHFLAG config.sh"
	exit 1
fi

${LOGGER} -t ${LOGGERTAG} "checking for ${PORTSTOREFRESHFLAG}"

if [ -r ${PORTSTOREFRESHFLAG} ]
then
	${LOGGER} -t ${LOGGERTAG} "found, now processing"
	rm ${PORTSTOREFRESHFLAG}
	/usr/local/bin/perl ./refresh-ports.pl
else
	${LOGGER} -t ${LOGGERTAG} "not found"
fi

${LOGGER} -t ${LOGGERTAG} "finished"
