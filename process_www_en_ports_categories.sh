#!/bin/sh
#
# $Id: process_www_en_ports_categories.sh,v 1.4 2007-10-16 19:01:41 dan Exp $
#
# Copyright (c) 2003-2007 DVL Software Limited
#

LOGGERTAG="process_www_en_ports_categories.sh"

${LOGGER} -t ${LOGGERTAG} has been invoked

if [ ! -f config.sh ]
then
	echo "config.sh not found by process_www_en_ports_categories.sh..."
	exit 1
fi

. config.sh

if [ $OFFLINE = 1 ]
then
	${LOGGER} -t ${LOGGERTAG} -t FreshPorts system is OFFLINE ... exiting
	exit 0
fi

if [ "${WWWENPORTSCATEGORIES}x" = 'x' -o "${SPOOLINGDIR}x" = 'x' ]
then
	echo "please set WWWENPORTSCATEGORIES and SPOOLINGDIR in config.sh"
	exit 1
fi

CATEGORIES="${SPOOLINGDIR}/categories"

if [ -r ${WWWENPORTSCATEGORIES} ]
then
	${LOGGER} -t ${LOGGERTAG} -t FreshPorts invoking categories_update_descriptions.pl with ${CATEGORIES}
	/usr/local/bin/perl categories_update_descriptions.pl ${CATEGORIES}

	# regardless of any errors, we should remove this as we don't want to keep doing this
	rm ${WWWENPORTSCATEGORIES}
else
	${LOGGER} -t ${LOGGERTAG} was invoked but ${WWWENPORTSCATEGORIES} was not set.
fi
