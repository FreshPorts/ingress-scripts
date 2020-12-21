#!/bin/sh
#
# $Id: daily_rendering_times.sh,v 1.2 2006-12-17 12:04:00 dan Exp $
#
# Copyright (c) 2004 DVL Software Limited
#
# archive away all the messages which were created yesterday.
# this script is designed to be called like this from crontab:
#
#  10  0   *   *   *  cd $DIR && ./daily_rendering_times.sh.sh 1 >> /dev/null
#
# where $DIR is the directory in which this file exists.


if [ $# -ne 1 ]
then
   echo $0 : usage $0 DAYS
   exit 1
fi

if [ ! -f config.sh ]
then
	echo "config.sh not found by daily_rendering_times.sh..."
	exit 1
fi

. config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

DAYS=$1

YYYY_MM_DD=$(eval date -v-${DAYS}d "+%Y-%m-%d")

/usr/local/bin/perl ${SCRIPTDIR}/daily_rendering_times.pl ${YYYY_MM_DD}
