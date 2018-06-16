#!/bin/sh
#
# $Id: process_CVSROOT_approvers.sh,v 1.5 2007-10-16 18:59:54 dan Exp $
#
# Copyright (c) 2003-2004 DVL Software Limited
#

LOGGERTAG="process_CVSROOT_approvers.sh"

if [ ! -f config.sh ]
then
	echo "config.sh not found by process_CVSROOT_approvers.sh..."
	${LOGGER} -t ${LOGGERTAG} "config.sh not found..."
	exit 1
fi

. config.sh

if [ "${PORTSFREEZEFILE}x" = 'x' ]
then
	echo "please set PORTSFREEZEFILE in config.sh"
	${LOGGER} -t ${LOGGERTAG} "please set PORTSFREEZEFILE in config.sh"
	exit 1
fi

if [ ! -r $1 ]
then
	echo "please supply the file name for CVSROOT_Approvers as the first parameter."
	${LOGGER} -t ${LOGGERTAG} "please supply the file name for CVSROOT_Approvers as the first parameter."
	exit 1
fi

egrep -v -q '^#|^$' $1
if [ $? = 0 ]
then
	touch ${PORTSFREEZEFILE}
else
	if [ -f ${PORTSFREEZEFILE} ]
	then
		rm ${PORTSFREEZEFILE}
	fi
fi
