#!/bin/sh
#
# $Id: cache-refresh.sh,v 1.2 2006-12-17 12:03:59 dan Exp $
#
# Copyright (c) 2004 DVL Software Limited
#

LOGGERTAG="cache-refresh.sh"

if [ ! -f config.sh ]
then
	echo "config.sh not found by cache-refresh.sh..."
	exit 1
fi

. config.sh

${LOGGER} -t ${LOGGERTAG} "cache-refresh.sh needs to be rewritten to mv files to the correct places"

if [ $OFFLINE = 1 ]
then
	exit 0
fi

if [ "${WEBSITEURL}x" = "x" ]
then
	${LOGGER} -t ${LOGGERTAG} 'define WEBSITEURL in config.sh first'
	exit 1
fi

if [ "${SPOOLINGDIR}x" = "x" ]
then
	${LOGGER} -t ${LOGGERTAG}  'define SPOOLINGDIR in config.sh first'
	exit 1
fi

if [ "${CACHE_NEEDS_REFRESH}x" = 'x' ]
then
	${LOGGER} -t ${LOGGERTAG}  "please set CACHE_NEEDS_REFRESH in config.sh"
	exit 1
fi

echo ${NEWSCACHEDIR}
echo ${SPOOLINGDIR}
echo ${CACHE_NEEDS_REFRESH}

if [ -r ${CACHE_NEEDS_REFRESH} ]
then
	#
	# the following remove the old news feeds
	#
	/bin/rm -f ${NEWSCACHEDIR}/*.xml

	${FETCH} ${FETCH_OPTIONS} ${SPOOLINGDIR}/index.html      ${WEBSITEURL}/caching-files/index.php?numcommits=10
	${FETCH} ${FETCH_OPTIONS} ${SPOOLINGDIR}/commits.html    ${WEBSITEURL}/caching-files/index.php?numcommits=100
	${FETCH} ${FETCH_OPTIONS} ${SPOOLINGDIR}/news.rss        ${WEBSITEURL}/caching-files/news.php
	${FETCH} ${FETCH_OPTIONS} ${SPOOLINGDIR}/ports-new.rss   ${WEBSITEURL}/caching-files/ports-new.php

	${FETCH} ${FETCH_OPTIONS} ${SPOOLINGDIR}/categories-by-category.html    ${WEBSITEURL}/caching-files/categories.php

	#
	# because of these wild cards, we need to have exclusive use of SPOOLINGDIR
	#
	/bin/chmod g+r ${SPOOLINGDIR}/*

	/bin/mv ${SPOOLINGDIR}/* ${CACHEDIR}/

	#
	# remove the flag
	#
	/bin/rm "${CACHE_NEEDS_REFRESH}"
else
	${LOGGER} -t ${LOGGERTAG} ${CACHE_NEEDS_REFRESH} not set
fi
