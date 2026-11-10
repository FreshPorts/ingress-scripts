#!/bin/sh

# re: https://github.com/FreshPorts/freshports/issues/488
# usually invoked by a periodic script
# Let's cache the list of categories for searching.

. /usr/local/etc/freshports/config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

#
# save these values for use by psql via environment variables. The password is stored in ~/.pgpass
#
export PGDATABASE=$DB
export PGHOST=$HOST
export PGUSER=$DBUSER

# The temporary file goes in HTMLROOT itself, not SPOOLINGDIR: they are
# separate ZFS filesystems, so a mv between them is a copy, and www could
# read a half-written categories.php.  Within one filesystem, mv is an
# atomic rename.
#
# If the temporary file cannot be made, stop: there is nothing to write
# to, and the categories.php www is using stays as it is.
#
SPOOL_FILE=$(mktemp ${HTMLROOT}/.categories.php.XXXXXX) || {
	logger -p local3.error -t FreshPorts $0 could not create a temporary file in ${HTMLROOT} - FATAL
	exit 1
}

#
# The whole file comes from this one query.  Its first select is the
# "all" entry at the top of the search page's Category dropdown: a blank
# value, which means search every category, and the default.  The second
# select is one entry per category.
#
# Nothing can be written to the file before psql runs: --output empties
# the file when psql opens it.  This script used to write the "all" line
# with cat first, and psql always threw that copy away; the entry on the
# page has only ever come from the query.
#
psql -t --output=${SPOOL_FILE} <<EOF
select '            <OPTION VALUE=""<?php if (\$category == '''') echo '' SELECTED''?>>all</OPTION>'
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
