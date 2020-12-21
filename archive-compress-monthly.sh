#!/bin/sh
#
# $Id: archive-compress-monthly.sh,v 1.1 2002-02-02 17:04:49 dan Exp $
#
# Copyright (c) 2001 DVL Software Limited
#
# given an archive in ARCHIVEDIR/YYYY_MM, tar it up and remove the original
#

if [ $# -ne 2 ]
then
   echo $0 : usage $0 MONTHS ARCHIVEDIR
   exit 1
fi

ARCHIVEDIR=$2

YYYY_MM=$(eval date -v1d -v-$1m "+%Y_%m")

cd ${ARCHIVEDIR}
tar cvfz ${YYYY_MM}.tgz ${YYYY_MM} && rm -rf ${YYYY_MM}
