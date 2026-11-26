#!/bin/sh

# get the name of this script
LOGGERTAG=${0##*/}

QUERYBASE='from ports_active PA WHERE NOT EXISTS (SELECT port_id, category_id from ports_categories PC where PC.port_id = PA.id and PC.category_id = PA.category_id)'
QUERYROWS="select id, category_id, name, category, category || '/' || name AS port, element_pathname(element_id)"
QUERYORDER="ORDER BY category, name"

if [ ! -f config.sh ]
then
	/usr/bin/logger -p local3.err -t FreshPorts "config.sh not found by $0"
	echo "config.sh not found by $0"
	exit 1
fi

. config.sh

if [ $OFFLINE = 1 ]
then
	$LOGGER -t $LOGGERTAG "exit now because the system is OFFLINE"
	exit 0
fi

#
# One query for both the count and the list, so they come from the same
# snapshot and cannot disagree.  The count is taken from psql's footer,
# "(1 row)" or "(N rows)".
#
# sslcertmode=disable avoids: could not open certificate file
# "/root/.postgresql/postgresql.crt": Permission denied
# Without it, the list query used to fail and the mail went out with no list.
#
CONNECTION="sslcertmode=disable host=${HOST} dbname=${DB} user=${DBUSER}"

$LOGGER -t $LOGGERTAG "Checking for ports without ports_categories entries"
PORTS=$(${PSQL} -q --no-psqlrc -v ON_ERROR_STOP=1 "${CONNECTION}" -c "${QUERYROWS} ${QUERYBASE} ${QUERYORDER}" 2>&1)
RESULT=$?
if [ $RESULT != 0 ]
then
  $LOGGER -t $LOGGERTAG "FATAL: psql failed with exit status $RESULT: $PORTS"
  echo "$PORTS" | mail -s "missing-port-categories.sh: psql failed on ${WEBSITEURL}" ${ADMINEMAIL}
  # job-waiting.pl reruns us while the flag is up; the mail has said it all
  rm -f $CHECKPORTSCATEGORIESFILE
  exit 1
fi

ROWCOUNT=$(echo "$PORTS" | sed -n 's/^(\([0-9]*\) rows*)$/\1/p')
$LOGGER -t $LOGGERTAG "found this many invalid entries: $ROWCOUNT"
if [ "${ROWCOUNT}" != "0" ]
then
  # mktemp, not /tmp/missing-ports.$$: a name made from the PID can be
  # guessed and created first, and one left by a run which died is
  # appended to by a later run which gets the same PID.
  TMPFILE=$(mktemp -t missing-ports)
  if [ $? -ne 0 ]
  then
    $LOGGER -t $LOGGERTAG "FATAL: could not create a temporary file for the mail"
    # job-waiting.pl reruns us while the flag is up
    rm -f $CHECKPORTSCATEGORIESFILE
    exit 1
  fi
  echo 'This is a list of ports that do not have entries in the ports_categories table' >> ${TMPFILE}
  echo 'This can be fixed with this query:'  >> ${TMPFILE}
  echo >> ${TMPFILE}
  echo 'begin;  insert into ports_categories select id, category_id from ports_active PA WHERE NOT EXISTS (SELECT * from ports_categories PC where PC.port_id = PA.id and PC.category_id = PA.category_id);'  >> ${TMPFILE}
  echo >> ${TMPFILE}
  echo 'This is a list of the ports in question:' >> ${TMPFILE}
  echo >> ${TMPFILE}
  echo "$PORTS" >> ${TMPFILE}
  cat  ${TMPFILE} | mail -s "missing ports_categories entries on ${WEBSITEURL}" ${ADMINEMAIL}
  rm ${TMPFILE}
fi

# remove our signal file
rm -f $CHECKPORTSCATEGORIESFILE
