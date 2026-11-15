#!/bin/sh

#
# Dump the packages_last_checked table
# Typically, this script is invoked by /usr/local/etc/periodics/hourly/990.refresh_package_imports_page
#

if [ $# -ne 1 ]
then
   echo "$0 : usage $0 (name|date)"
   exit 1
fi

# we accept only two values: name, date
case $1 in
  name)
    SORT_BY='name, package_set'
    ;;
  date)
    SORT_BY='repo_date desc nulls last, name, package_set'
    ;;
  *)
    echo "$0 : usage $0 (name|date)"
    exit 1
esac



if [ ! -f config.sh ]
then
	echo "config.sh not found by $0"
	exit 1
fi

. config.sh

if [ "$OFFLINE" = 1 ]
then
	exit 0
fi

$LOGGER -t $0[$$] starts

#
# When I copied this script from refresh-abi.sh, I thought: where is the connection information?
# Where is the database and user specified?
# It's right here, these three environment variables.
# See https://www.postgresql.org/docs/current/libpq-envars.html
# The password is stored in ~/.pgpass
#
export PGDATABASE=$DB
export PGHOST=$HOST
export PGUSER=$DBUSER_REPORTING

# see also PGSSLMODE and PGSSLROOTCERT in config.sh


sql=$( mktemp ${SPOOLINGDIR}/packages_last_checked-sql.XXXXXX)  || exit 1
data=$(mktemp ${SPOOLINGDIR}/packages_last_checked-data.XXXXXX) || exit 1

# fetch and extract the contents of packages_last_checked
# data to be fetched
echo 'select abi.name, PLC.* from packages_last_checked PLC join abi on plc.abi_id = abi.id order by ' >> $sql
echo "$SORT_BY;" >> $sql

# Run the SQL. ON_ERROR_STOP=1 makes psql exit non-zero (3) when the
# query fails; without it, psql -f exits 0 after an SQL error. A failed
# connection already exits 2.
psql -v ON_ERROR_STOP=1 -f $sql >> $data
psql_rc=$?

# On success, print the data and remove both temp files.
#
# On failure, print nothing, keep both files for debugging, log where
# they are, and exit 1. The caller, hourly/990.refresh_package_imports_page
# in FreshPorts periodics, then keeps the previous copy of the page
# instead of replacing it with this script's empty output.
if [ $psql_rc -eq 0 ]
then
  cat $data
  rm $data $sql
else
  $LOGGER -t $0[$$] fatal error: psql exited $psql_rc - see sql at $sql and output at $data
  exit 1
fi

$LOGGER -t $0[$$] finishes
