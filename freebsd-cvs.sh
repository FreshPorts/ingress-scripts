#!/bin/sh
#
# $Id: freebsd-cvs.sh,v 1.9 2011-08-15 16:31:56 dan Exp $
#
# Copyright (c) 1999-2003 DVL Software
#
# Process a raw mail message by converting it to XML, then importing it into
# the database.
#
# Takes a file name as a parameter
#

if [ $# -ne 1 ]
then
   echo $0 : usage $0 FILE
   exit 1
fi

if [ ! -f config.sh ]
then
	echo "config.sh not found by freebsd-cvs.sh..."
	exit 1
fi

. config.sh

echo $0 has started

if [ $OFFLINE = 1 ]
then
	exit 0
fi

XML="/var/db/ingress_svn/message-queues/spooling"

echo "$0 invoked, using XML='${XML}'"

PATHNAME=$1

FILE=$(basename ${PATHNAME}) 

#
# convert the raw file to XML
#
echo "$0 converting to XML via process_mail.pl"
echo /usr/local/bin/perl ${SCRIPTDIR}/process_mail.pl from ${PATHNAME} into ${XML}/${FILE}.xml errors to ${XML}/${FILE}.errors

/usr/local/bin/perl ${SCRIPTDIR}/process_mail.pl < ${PATHNAME} > ${XML}/${FILE}.xml 2>${XML}/${FILE}.errors
RESULT=$?



if [ -f ${XML}/${FILE}.errors ]
then
#  found errors
   if [  -s $XML/$FILE.errors ]
   then
      exit 2
   else
      rm $XML/$FILE.errors
   fi
fi

echo "$0 finished"

exit $RESULT
