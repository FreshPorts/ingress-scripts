#!/bin/sh
#
# $Id: fetch-svn-file.sh,v 1.6 2012-08-15 11:49:10 dan Exp $
#
# Copyright (c) 1999-2026 Dan Langille
#
# This script used to fetch files from the svn repo into our own tree.

echo "num of params = $#"
if  [ $# -ne 7 ];
	then echo error invoking script $0 : usage $0 URL DESTDIR SRCDIR FILE REVISION SUFFIX 1>&2
	exit 1
else
	URL=$1
	REPO=$2
	DESTDIR=$3
	SRCDIR=$4
	FILE=$5
	REVISION=$6
	SUFFIX=$7

	mkdir -p ${DESTDIR}
	if [ $? -ne 0 ]
	then
		exit 3
	fi

	FETCHFILE=$DESTDIR/$FILE

	# try to get around any possible caching by using a timestamp as a parameter
	#
	time=$(/bin/date +"%s")

    # we may not need this cd...
    cd ${DESTDIR}
    echo "svn up -r ${REVISION} ${FETCHFILE}"
    svn up -r ${REVISION} ${FETCHFILE}
	exit $?
fi
