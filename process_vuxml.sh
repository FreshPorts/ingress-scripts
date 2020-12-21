#!/bin/sh
#
# $Id: process_vuxml.sh,v 1.7 2012-07-24 15:56:40 dan Exp $
#
# Copyright (c) 2003-2005 DVL Software Limited
#
# Check to see if the switch is set, and if so, load the
# security/vuxml/vuln.xml file into the database
#
#  3-59/7  *   *   *   *  cd $DIR && ./process_vuxml.sh >> /dev/null
#
# where $DIR is the directory in which this file exists.
#
# file switch, set by commit processing script
# That file 

LOGGERTAG="process_vuxml.sh"

if [ ! -f config.sh ]
then
	exit 1
fi

. config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

if [ "${VUXMLFLAGFILE}x" = 'x' -o "${PORTSDIR}x" = 'x' -o "${VUXMLMUTEX}x" = 'x' -o "${DIRLOG}x" = 'x' ]
then
	${LOGGER} -t ${LOGGERTAG} "please set all of VUXMLFLAGFILE, PORTSDIR, VUXMLMUTEX, and DIRLOG in config.sh"
	exit 1
fi

if [ -f ${VUXMLMUTEX} ]
then
	${LOGGER} -t ${LOGGERTAG} "${VUXMLMUTEX} is set.  vuxml processing is already underway"
	exit 0
fi

LOGFILE=${DIRLOG}/vuxml.log

if [ -r ${VUXMLFLAGFILE} ]
then
	touch ${VUXMLMUTEX}
	rm ${VUXMLFLAGFILE}
	${LOGGER} -t ${LOGGERTAG} "vuxml processing begins"
	echo $(date) "${LOGGERTAG}"  "vuxml processing begins"                  >> ${LOGFILE}
	
	# define the vuln file we are going to operate on
	VULNFILE="${FRESHPORTS_JAIL_BASE_DIR}${PORTSDIR}/security/vuxml/vuln.xml"
	
	${LOGGER} -t ${LOGGERTAG} "process_vuxml.pl begins on ${VULNFILE}"
	/usr/local/bin/perl ./process_vuxml.pl < ${VULNFILE} >> ${LOGFILE}
	if [ $? -eq 0 ]
	then
	  ${LOGGER} -t ${LOGGERTAG} "process_vuxml.pl finishes normally"
	else
	  ${LOGGER} -t ${LOGGERTAG} "FATAL process_vuxml.pl finished with an error: $?"
	fi

	${LOGGER} -t ${LOGGERTAG} "vuxml_ident.pl begins on ${VULNFILE}"
	/usr/local/bin/perl ./vuxml_ident.pl ${VULNFILE} > ${HTMLROOT}/vuxml_revision
	if [ $? -eq 0 ]
	then
	  ${LOGGER} -t ${LOGGERTAG} "vuxml_ident.pl finishes normally"
	else
	  ${LOGGER} -t ${LOGGERTAG} "FATAL vuxml_ident.pl finished with an error: $?"
	fi

	${LOGGER} -t ${LOGGERTAG} "vuln_latest.pl begins"
	/usr/local/bin/perl ./vuln_latest.pl >> ${LOGFILE}
	if [ $? -eq 0 ]
	then
	  ${LOGGER} -t ${LOGGERTAG} "vuln_latest.pl finishes normally"
	else
	  ${LOGGER} -t ${LOGGERTAG} "FATAL vuln_latest.pl finished with an error: '$?' - see ${LOGFILE} for error messsages"
	fi

	rm ${VUXMLMUTEX}
	echo $(date) "${LOGGERTAG}"  "vuxml finishes" >> ${LOGFILE}
	${LOGGER} -t ${LOGGERTAG} "vuxml finishes"
else
	${LOGGER} -t ${LOGGERTAG} "${VUXMLFLAGFILE} not set: no processing to do"
fi
echo $(date) "${LOGGERTAG}"  "vuxml terminates" >> ${LOGFILE}
${LOGGER} -t ${LOGGERTAG} "vuxml terminates"
