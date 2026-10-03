#!/bin/sh
#
# $Id: archive-compress.sh,v 1.4 2002-02-02 17:04:49 dan Exp $
#
# Copyright (c) 1999-2026 Dan Langille
#
# I'm not so sure this is used any more
#

#if [ $# -ne 1 ]
#then
#   echo $0 : usage $0 YYYY_MM 1>&2
#   exit 1
#fi

YYYY_MM=$(date -v1d  -v-1d "+%Y_%m")

ARCHIVEDIR="/usr/local/etc/freshports/msgs/archives"

cd $ARCHIVEDIR

#
# create the directory if needed
#

if [ ! -d ${YYYY_MM} ]
then
   mkdir ${YYYY_MM}
fi

#
# we do a cd so as not to include the whole path in the tarball
#
tar cfz ${YYYY_MM}.tgz ./${YYYY_MM}/* 
if [ $? -ne 0 ]
then
  echo tar failed
  exit
fi

chmod -w ${YYYY_MM}.tgz

rm -rf $ARCHIVEDIR/${YYYY_MM}
