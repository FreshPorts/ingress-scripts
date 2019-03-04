#!/bin/sh

QUERYBASE='from ports_active PA WHERE NOT EXISTS (SELECT port_id, category_id from ports_categories PC where PC.port_id = PA.id and PC.category_id = PA.category_id)'
QUERYCOUNT='select count(id)'
QUERYROWS="select id, category_id, name, category, category || '/' || name AS port, element_pathname(element_id)"
QUERYORDER="ORDER BY category, name"

if [ ! -f config.sh ]
then
	echo "config.sh not found by missing-port-categories.sh..."
	exit 1
fi

. config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi
echo Checking for ports without ports_categories entries
echo      ${PSQL} -h ${HOST} -q --pset t -d ${DB} --user ${DBUSER} -c "${QUERYCOUNT} ${QUERYBASE}" 
ROWCOUNT=`${PSQL} -h ${HOST} -q --pset t -d ${DB} --user ${DBUSER} -c "${QUERYCOUNT} ${QUERYBASE}"`
echo $ROWCOUNT found
if [ ${ROWCOUNT} -ne 0 ]
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
