#!/bin/sh
#
# $Id: archive-messages.sh,v 1.2 2006-12-17 12:03:59 dan Exp $
#
# Copyright (c) 2003 DVL Software Limited
#
# archive away all the messages which were created yesterday.
# this script is designed to be called like this from crontab:
#
#  10  0   *   *   *  cd $DIR && ./archive-messages.sh 1 >> /dev/null
#
# where $DIR is the directory in which this file exists.

if [ $# -ne 1 ]
then
   echo $0 : usage $0 DAYS
   exit 1
fi

if [ ! -f config.sh ]
then
	echo "config.sh not found by archive-messages.sh..."
	exit 1
fi

. config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

DAYS=$1

YYYY_MM_DD=$(eval date -v-${DAYS}d "+%Y_%m_%d")
YYYY_MM=$(eval date -v-${DAYS}d "+%Y_%m")
YYYYMMDD=$(eval date -v-${DAYS}d "+%Y.%m.%d")


DEST="${MSGDIR}/archive/${YYYY_MM}/${YYYY_MM_DD}/"
mkdir -p ${DEST}

# the -d 1 is so I can mkdir erorrs && mv stuff errors and keep them around
find ${MSGDIR}/recent -type f -d 1 -name ${YYYYMMDD}\* | xargs -n 1 -J {} mv {} ${DEST}
