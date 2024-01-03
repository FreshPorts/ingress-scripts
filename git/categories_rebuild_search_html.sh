#!/bin/sh

# re: https://github.com/FreshPorts/freshports/issues/488
# usually invoked by a periodic script
# Let's cache the list of categories for searching.

. /usr/local/etc/freshports/config.sh

#
# save these values for use by psql via environment variables. The password is stored in ~/.pgpass
#
export PGDATABASE=$DB
export PGHOST=$HOST
export PGUSER=$DBUSER

SPOOL_FILE=$(mktemp ${SPOOLINGDIR}/categories.XXXXXX)

cat << EOF > ${SPOOL_FILE}
             <OPTION VALUE=""<?php if ($category == '') echo ' SELECTED'?>></OPTION>
EOF

#
# we need a blank entry as a default value
#
psql -t --output=${SPOOL_FILE} <<EOF
select '            <OPTION VALUE=""<?php if (\$category == '''') echo '' SELECTED''?>></OPTION>'
UNION
select '            <OPTION VALUE="'  || name || '"<?php if (\$category == ''' || name || ''') echo '' SELECTED''?>>' || name || '</OPTION>' from categories order by 1;
EOF

if [ $? -ne 0 ]
then
	logger -p local3.error -t FreshPorts $0 errored when running psql - FATAL
	rm ${SPOOL_FILE}
	exit 1
fi

# the output should be at least 12K
size=$(stat -f %z ${SPOOL_FILE})
if [ $size -lt 12000 ]
then
	# exit and log
	logger -p local3.error -t FreshPorts $0 created a file smaller than expected. Aborting. - FATAL
	rm ${SPOOL_FILE}
	exit 1
fi

chmod +r ${SPOOL_FILE}
mv ${SPOOL_FILE} ${HTMLROOT}/categories.php
logger -p local3.notice -t FreshPorts $0 has completed.
