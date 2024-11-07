#!/bin/sh
#
# $Id: process_updating.sh,v 1.2 2006-12-17 12:04:02 dan Exp $
#
# Copyright (c) 2003-2004 DVL Software Limited
#
# Check to see if the switch is set, and if so, load the
# /usr/ports/UPDATING file into the database
#
#  3-59/7  *   *   *   *  cd $DIR && ./process_updating.sh >> /dev/null
#
# where $DIR is the directory in which this file exists.
#
# file switch, set by commit processing script
# That file 

logger -p local3.notice -t FreshPorts $0 is starting

if [ ! -f config.sh ]
then
	logger -p local3.notice -t FreshPorts "config.sh not found by $0"
	echo "config.sh not found by $0"
	exit 1
fi

. config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

if [ "${UPDATINGFLAGFILE}x" = 'x' -o "${PORTSDIR}x" = 'x' ]
then
	logger -p local3.notice -t FreshPorts "please set UPDATINGFLAGFILE and PORTSDIR in config.sh"
	echo "please set UPDATINGFLAGFILE and PORTSDIR in config.sh"
	exit 1
fi

if [ -r ${UPDATINGFLAGFILE} ]
then
	rm ${UPDATINGFLAGFILE}
	logger -p local3.notice -t FreshPorts "about to run: /usr/local/bin/perl ./process_updating.pl < ${FRESHPORTS_JAIL_BASE_DIR}/${PORTSDIR}/UPDATING"
	/usr/local/bin/perl ./process_updating.pl < ${FRESHPORTS_JAIL_BASE_DIR}/${PORTSDIR}/UPDATING > ${DIRLOG}/process_updating.log
else
    logger -p local3.notice -t FreshPorts $0 invokved but ${UPDATINGFLAGFILE} was not set.
fi

logger -p local3.notice -t FreshPorts $0 is finishing
