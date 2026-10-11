#!/bin/sh
#
# $Id: process_vuxml.sh,v 1.7 2012-07-24 15:56:40 dan Exp $
#
# Copyright (c) 2003-2026 Dan Langille
#

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

echo $(date) "${LOGGERTAG}"  "vuxml starts" >> ${LOGFILE}
${LOGGER} -t ${LOGGERTAG} "vuxml starts"
if [ -r ${VUXMLFLAGFILE} ]
then
	touch ${VUXMLMUTEX}
	rm ${VUXMLFLAGFILE}
	${LOGGER} -t ${LOGGERTAG} "vuxml processing begins"
	echo $(date) "${LOGGERTAG}"  "vuxml processing begins"                      >> ${LOGFILE}
	
	# define the vuln file we are going to operate on
	VULNSRC="${FRESHPORTS_JAIL_BASE_DIR}${PORTSDIR}/security/vuxml/vuln.xml"

	# vuln.xml pulls in vuln/*.xml via external entities. expat's billion
	# laughs protection treats that expansion as an attack and aborts with
	# "limit on input amplification factor (from DTD and entities) breached".
	# Flatten it first so the parser sees no entities to expand.
	# See https://news.freshports.org/2024/11/23/vuxml-processing-broken-files-have-grown-too-much/
	VULNFILE=$(mktemp -t vuln-flat)
	if [ $? -ne 0 ]
	then
		${LOGGER} -t ${LOGGERTAG} "FATAL could not create temp file for flattened vuln.xml"
		rm ${VUXMLMUTEX}
		exit 1
	fi

	${LOGGER} -t ${LOGGERTAG} "flattening ${VULNSRC} into ${VULNFILE}"
	echo $(date) "flattening ${VULNSRC} into ${VULNFILE}"                       >> ${LOGFILE}
	/usr/local/bin/xmllint --noent --dropdtd --nonet ${VULNSRC} > ${VULNFILE} 2>> ${LOGFILE}
	if [ $? -ne 0 ]
	then
		${LOGGER} -t ${LOGGERTAG} "FATAL xmllint could not flatten ${VULNSRC} - see ${LOGFILE}"
		rm -f ${VULNFILE}
		rm ${VUXMLMUTEX}
		exit 1
	fi

	${LOGGER} -t ${LOGGERTAG} "process_vuxml.pl begins on ${VULNFILE}"
	echo $(date) "process_vuxml.pl begins on ${VULNFILE}"                       >> ${LOGFILE}
	${LOGGER} -t ${LOGGERTAG} "there is often a delay before the next message"
	echo $(date) "there is often a delay before the next message"               >> ${LOGFILE}
	/usr/local/bin/perl ./process_vuxml.pl --filename=${VULNFILE} --showreasons >> ${LOGFILE}
	if [ $? -eq 0 ]
	then
	  ${LOGGER} -t ${LOGGERTAG} "process_vuxml.pl finishes normally"
	else
	  ${LOGGER} -t ${LOGGERTAG} "FATAL process_vuxml.pl finished with an error: $?"
	fi

	rm -f ${VULNFILE}

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
