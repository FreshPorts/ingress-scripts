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
	
	# Read security/vuxml from origin/main, not from the working tree.
	# Commit processing leaves the tree at the last commit it loaded, which
	# can be on a quarterly branch, and VuXML is maintained only on main: a
	# quarterly tree has an older vuln.xml.  A run against it deletes the
	# vulns added since (the "deleting way too many rows" guard stops that)
	# and puts every vuln changed since back to its old text.  A run started
	# by a VuXML commit always sees main, but one started by hand may not.
	# git archive reads the local clone only; it does not fetch.
	PORTSREPO="${FRESHPORTS_JAIL_BASE_DIR}${PORTSDIR}"
	VUXMLREF=${VUXMLREF:-origin/main}
	VUXMLDIR=$(mktemp -d -t vuxml-main)
	if [ $? -ne 0 ]
	then
		${LOGGER} -t ${LOGGERTAG} "FATAL could not create temp directory for security/vuxml"
		rm ${VUXMLMUTEX}
		exit 1
	fi

	/usr/local/bin/git -c safe.directory=${PORTSREPO} -C ${PORTSREPO} archive ${VUXMLREF} security/vuxml | tar -xf - -C ${VUXMLDIR}
	VULNSRC="${VUXMLDIR}/security/vuxml/vuln.xml"
	if [ ! -s ${VULNSRC} ]
	then
		${LOGGER} -t ${LOGGERTAG} "FATAL could not extract security/vuxml from ${VUXMLREF} in ${PORTSREPO}"
		echo $(date) "FATAL could not extract security/vuxml from ${VUXMLREF} in ${PORTSREPO}" >> ${LOGFILE}
		rm -rf ${VUXMLDIR}
		rm ${VUXMLMUTEX}
		exit 1
	fi

	echo $(date) "reading security/vuxml from ${VUXMLREF}:" $(/usr/local/bin/git -c safe.directory=${PORTSREPO} -C ${PORTSREPO} log -1 --format='%h %ci %s' ${VUXMLREF} -- security/vuxml) >> ${LOGFILE}

	# vuln.xml pulls in vuln/*.xml via external entities. expat's billion
	# laughs protection treats that expansion as an attack and aborts with
	# "limit on input amplification factor (from DTD and entities) breached".
	# Flatten it first so the parser sees no entities to expand.
	# See https://news.freshports.org/2024/11/23/vuxml-processing-broken-files-have-grown-too-much/
	VULNFILE=$(mktemp -t vuln-flat)
	if [ $? -ne 0 ]
	then
		${LOGGER} -t ${LOGGERTAG} "FATAL could not create temp file for flattened vuln.xml"
		rm -rf ${VUXMLDIR}
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
		rm -rf ${VUXMLDIR}
		rm ${VUXMLMUTEX}
		exit 1
	fi

	# the flattened copy is all process_vuxml.pl needs
	rm -rf ${VUXMLDIR}

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
