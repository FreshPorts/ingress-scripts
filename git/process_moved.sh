#!/bin/sh
#
# $Id: process_moved.sh,v 1.2 2006-12-17 12:04:02 dan Exp $
#
# Copyright (c) 2003-2004 DVL Software Limited
#
# Check to see if the switch is set, and if so, load the
# /usr/ports/MOVED file into the database
#
#  3-59/7  *   *   *   *  cd $DIR && ./process_moved.sh >> /dev/null
#
# where $DIR is the directory in which this file exists.
#
# file switch, set by commit processing script
# That file 

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

if [ "${MOVEDFLAGFILE}x" = 'x' -o "${PORTSDIR}x" = 'x' -o "${FRESHPORTS_JAIL_BASE_DIR}x" = 'x' ]
then
	echo "please set MOVEDFLAGFILE, PORTSDIR, and FRESHPORTS_JAIL_BASE_DIR in config.sh"
	exit 1
fi

if [ -r "${FRESHPORTS_JAIL_BASE_DIR}${PORTSDIR}/MOVED" -a -f "${FRESHPORTS_JAIL_BASE_DIR}${PORTSDIR}/MOVED" ]
then
    # all good
else
   echo "\${FRESHPORTS_JAIL_BASE_DIR}\${PORTSDIR}/MOVED evaluates to '${FRESHPORTS_JAIL_BASE_DIR}${PORTSDIR}/MOVED' which is not a readable file or does not exist."
   exit 1
fi

if [ -r ${MOVEDFLAGFILE} ]
then
	rm ${MOVEDFLAGFILE}
	/usr/local/bin/perl ./process_moved.pl < ${FRESHPORTS_JAIL_BASE_DIR}/${PORTSDIR}/MOVED
fi
