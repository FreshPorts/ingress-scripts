#!/bin/sh
#
# Copyright (c) 2026 Dan Langille
#
# Rewrite vuxml.topic and vuxml.description from vuln.xml, without the
# delete, insert and commit marking process_vuxml.sh does.  See
# vuxml_fix_text.pl.
#
# Usage: vuxml_fix_text.sh [--dryrun] [--showvids]
#
# Run it as the freshports user, from this directory, like process_vuxml.sh.
#

LOGGERTAG="vuxml_fix_text.sh"

if [ ! -f config.sh ]
then
	echo "run this from the directory holding config.sh"
	exit 1
fi

. config.sh

if [ "${PORTSDIR}x" = 'x' -o "${VUXMLMUTEX}x" = 'x' -o "${DIRLOG}x" = 'x' ]
then
	echo "please set all of PORTSDIR, VUXMLMUTEX, and DIRLOG in config.sh"
	exit 1
fi

# process_vuxml.sh must not run at the same time
if [ -f ${VUXMLMUTEX} ]
then
	echo "${VUXMLMUTEX} is set.  vuxml processing is already underway"
	exit 1
fi

touch ${VUXMLMUTEX}

# remove the mutex and the temporary files however we leave, including ^C:
# a mutex left behind stops process_vuxml.sh, and this script, from running
VULNFILE=''
VUXMLDIR=''
trap 'rm -rf ${VULNFILE} ${VUXMLDIR} ${VUXMLMUTEX}' EXIT
trap 'exit 1' HUP INT TERM

LOGFILE=${DIRLOG}/vuxml.log

${LOGGER} -t ${LOGGERTAG} "starts $*"
echo $(date) "${LOGGERTAG}" "starts $*" >> ${LOGFILE}

# Read security/vuxml from head, not from the working tree.  Commit
# processing leaves the tree on whichever branch it processed last, and a
# quarterly branch has an older vuln.xml, missing the newest entries.
PORTSREPO="${FRESHPORTS_JAIL_BASE_DIR}${PORTSDIR}"
VUXMLREF=${VUXMLREF:-origin/main}
VUXMLDIR=$(mktemp -d -t vuxml-head)
if [ $? -ne 0 ]
then
	echo "FATAL could not create temp directory for security/vuxml"
	exit 1
fi

/usr/local/bin/git -c safe.directory=${PORTSREPO} -C ${PORTSREPO} archive ${VUXMLREF} security/vuxml | tar -xf - -C ${VUXMLDIR}
VULNSRC="${VUXMLDIR}/security/vuxml/vuln.xml"
if [ ! -s ${VULNSRC} ]
then
	echo "FATAL could not extract security/vuxml from ${VUXMLREF} in ${PORTSREPO}"
	exit 1
fi

echo "reading security/vuxml from ${VUXMLREF}:" $(/usr/local/bin/git -c safe.directory=${PORTSREPO} -C ${PORTSREPO} log -1 --format='%h %ci %s' ${VUXMLREF} -- security/vuxml)

# flatten vuln.xml, as process_vuxml.sh does, so expat sees no entities to expand
VULNFILE=$(mktemp -t vuln-flat)
if [ $? -ne 0 ]
then
	echo "FATAL could not create temp file for flattened vuln.xml"
	exit 1
fi

/usr/local/bin/xmllint --noent --dropdtd --nonet ${VULNSRC} > ${VULNFILE}
if [ $? -ne 0 ]
then
	echo "FATAL xmllint could not flatten ${VULNSRC}"
	exit 1
fi

/usr/local/bin/perl ./vuxml_fix_text.pl --filename=${VULNFILE} "$@"
RESULT=$?

${LOGGER} -t ${LOGGERTAG} "finishes"
echo $(date) "${LOGGERTAG}" "finishes" >> ${LOGFILE}

exit ${RESULT}
