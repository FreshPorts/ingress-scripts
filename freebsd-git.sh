#!/bin/sh
#
# $Id: freebsd-git.sh,v 1.9 2011-08-15 16:31:56 dan Exp $
#
# Copyright (c) 1999-2003 DVL Software
#
# Process a raw git log  message by converting it to XML, then importing it into
# the database.
#
# Takes a git commit hash a parameter
#
LOGGERTAG="freebsd-git.sh"

if [ $# -ne 1 ]
then
   echo $0 : usage $0 FILE
   exit 1
fi

if [ ! -f config.sh ]
then
	echo "config.sh not found by freebsd-git.sh..."
	exit 1
fi

. config.sh

${LOGGER} -t ${LOGGERTAG} $0 has started

if [ $OFFLINE = 1 ]
then
	exit 0
fi

XML="${MSGDIR}/recent"
OUTPUT="${MSGDIR}/recent"

${LOGGER} -t ${LOGGERTAG} "$0 invoked, using XML='${XML}' and OUTPUT='${OUTPUT}'"

PATHNAME=$1
FILE=`basename ${PATHNAME}` 

# should we start processing by commit-hash, we might need these two lines.
#PROCESS_ID=${$}
#FILE=`date +%Y.%m.%d.%H.%M.%S`.$PROCESS_ID.${COMMIT_HASH}.txt

#
# convert the raw file to XML
#
${LOGGER} -t ${LOGGERTAG} "$0 converting to XML via git-to-freshports-xml.py"

echo 
# output file 1to commit_hash.process_id so that if we process the same hash again, it does not conflict
${LOGGER} -t ${LOGGERTAG} ${SCRIPTDIR}/git-to-freshports-xml.py --path ${FRESHPORTS_JAIL_BASE_DIR}${PORTSDIR}-git --commit ${COMMIT_HASH} --output ${XML}/${FILE}.xml

exit

${SCRIPTDIR}/git-to-freshports-xml.py --path ${FRESHPORTS_JAIL_BASE_DIR}${PORTSDIR}-git --commit ${COMMIT_HASH} --output ${XML}/${FILE}.xml 2>${XML}/${FILE}.errors
RESULT=$?

if [ -f ${XML}/${FILE}.errors ]
then
#  found errors
   if [ -s $XML/$FILE.errors ]
   then
      exit 2
   else
      rm $XML/$FILE.errors
   fi
fi

#
# load the XML into the database
#

${LOGGER} -t ${LOGGERTAG} "$0 loading that XML into the database via load_xml_into_db_git.pl"

/usr/local/bin/perl ${SCRIPTDIR}/load_xml_into_db_git.pl ${XML}/${FILE}.xml ${OUTPUT}/${FILE}.loading 2>${OUTPUT}/$FILE.errors
RESULT=$?

if [ -f ${OUTPUT}/$FILE.errors ]
then
#  found errors
   if [ -s ${OUTPUT}/$FILE.errors ]
   then
      # do nothing, leave that file there.
   else
      rm ${OUTPUT}/$FILE.errors
   fi
fi

${LOGGER} -t ${LOGGERTAG} "$0 finished"


exit $RESULT
