#!/bin/sh

# get the name of this script
LOGGERTAG=${0##*/}

QUERYBASE='from ports_active PA WHERE NOT EXISTS (SELECT port_id, category_id from ports_categories PC where PC.port_id = PA.id and PC.category_id = PA.category_id)'
QUERYCOUNT='select count(id)'
QUERYROWS="select id, category_id, name, category, category || '/' || name AS port, element_pathname(element_id)"
QUERYORDER="ORDER BY category, name"

if [ ! -f config.sh ]
then
	echo "config.sh not found by $0"
	exit 1
fi

. config.sh

if [ $OFFLINE = 1 ]
then
	$LOGGER -t $LOGGERTAG "exit now because the system is OFFLINE"
	exit 0
fi

# this logging should be found /var/log/freshports.log
#
$LOGGER -t $LOGGERTAG "This is debug code for the periodic issue: failed: fe_sendauth: no password supplied"

$LOGGER -t $LOGGERTAG "Checking for the ${DBUSER} user password"
$LOGGER -t $LOGGERTAG "$(grep -l ${DBUSER} ~/.pgpass)"

# include the -- otherwise this gets interpreted as a argument: -rw------- 1 freshports freshports 230 Aug 28 13:47 /var/db/freshports/.pgpass
# and we get: logger: illegal option -- r
# usage: logger [-46Ais] [-f file] [-h host] [-P port] [-p pri] [-t tag]
#               [-S addr:port] [message ...]

# this sometimes gets a No such file or directory
$LOGGER -t $LOGGERTAG -- 'looking at my pgpass file'
$LOGGER -t $LOGGERTAG -- $(ls -l ~/.pgpass)
$LOGGER -t $LOGGERTAG -- 'looking at my home dir'
$LOGGER -t $LOGGERTAG -- $(ls -l ~/)
$LOGGER -t $LOGGERTAG -- 'moving to home dir'
cd ~
$LOGGER -t $LOGGERTAG -- 'what is over here?'
$LOGGER -t $LOGGERTAG -- $(pwd)
cd -
$LOGGER -t $LOGGERTAG -- 'and back again'

# so let's try a full path - the "who am i?" below is always showing: uid=10001(freshports) gid=10001(freshports) groups=10001(freshports)
$LOGGER -t $LOGGERTAG -- $(ls -l /var/db/freshports/.pgpass)

$LOGGER -t $LOGGERTAG "testing"
$LOGGER -t $LOGGERTAG "done checking for the user password"
$LOGGER -t $LOGGERTAG "who am i? $(id)"

$LOGGER -t $LOGGERTAG "Checking for ports without ports_categories entries"
$LOGGER -t $LOGGERTAG ${PSQL} -h ${HOST} -q --pset t -d ${DB} --user ${DBUSER} -c "${QUERYCOUNT} ${QUERYBASE}"
ROWCOUNT=$(${PSQL} -q --pset t "sslcertmode=disable host=${HOST} dbname=${DB} user=${DBUSER}" -c "${QUERYCOUNT} ${QUERYBASE}" | tr -d ' ')
$LOGGER -t $LOGGERTAG "found this many invalid entries: $ROWCOUNT"
if [ "${ROWCOUNT}" != "0" ]
then
  TMPFILE="/tmp/missing-ports.$$"
  echo 'This is a list of ports that do not have entries in the ports_categories table' >> ${TMPFILE}
  echo 'This can be fixed with this query:'  >> ${TMPFILE}
  echo >> ${TMPFILE}
  echo 'begin;  insert into ports_categories select id, category_id from ports_active PA WHERE NOT EXISTS (SELECT * from ports_categories PC where PC.port_id = PA.id and PC.category_id = PA.category_id);'  >> ${TMPFILE}
  echo >> ${TMPFILE}
  echo 'This is a list of the ports in question:' >> ${TMPFILE}
  echo >> ${TMPFILE}
  ${PSQL} -h ${HOST} -q -d ${DB} --user  ${DBUSER} -c "${QUERYROWS} ${QUERYBASE} ${QUERYORDER}"  >> ${TMPFILE}
  cat  ${TMPFILE} | mail -s "missing ports_categories entries on ${WEBSITEURL}" ${ADMINEMAIL}
  rm ${TMPFILE}
fi

# remove our signal file
rm -f $CHECKPORTSCATEGORIESFILE
