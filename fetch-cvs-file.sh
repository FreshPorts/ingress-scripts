#!/bin/sh
#
# $Id: fetch-cvs-file.sh,v 1.11 2007-03-17 13:12:07 dan Exp $
#
# Copyright (c) 1999-2001 DVL Software
#
# This script used to fetch files from the cvs repo into our own tree.
#
=======
#
# $Id: fetch-cvs-file.sh,v 1.11 2007-03-17 13:12:07 dan Exp $
#
# Copyright (c) 2000-2004 DVL Software
#
echo "num of params = $#"
if  [ $# -ne 6 ];
	then echo $0 : usage $0 URL DESTDIR SRCDIR FILE REVISION SUFFIX 1>&2
	exit 1
else
	URL=$1
	DESTDIR=$2
	SRCDIR=$3
	FILE=$4
	REVISION=$5
	SUFFIX=$6

	mkdir -p ${DESTDIR}
	if [ $? -ne 0 ]
	then
		exit 3
	fi

	FETCHFILE=$DESTDIR/$FILE

	# try to get around any possible caching by using a timestamp as a parameter
	#
	time=$(/bin/date +"%s")

	echo "* * * about to fetch '$URL/$SRCDIR/$FILE?rev=$REVISION$SUFFIX&cache_busting_value=$time'"
	echo "* * * fetching into $FETCHFILE"

	/usr/bin/fetch -A -o $FETCHFILE "$URL/~checkout~/$SRCDIR/$FILE?rev=$REVISION$SUFFIX&cache_busting_value=$time"
	exit $?
fi
