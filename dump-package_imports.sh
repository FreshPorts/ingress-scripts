#!/bin/sh

#
# Dump the packages_last_checked table
# Typically, this script is invoked by /usr/local/etc/periodics/hourly/990.refresh_package_imports_page
#

if [ ! -f config.sh ]
then
	echo "config.sh not found by $0"
	exit 1
fi

. config.sh

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


sql=$( mktemp ${SPOOLINGDIR}/packages_last_checked-sql.XXXXXX)
data=$(mktemp ${SPOOLINGDIR}/packages_last_checked-data.XXXXXX)

# fetch and extract the contents of packages_last_checked
# data to be fetched
echo 'select abi.name, PLC.* from packages_last_checked PLC join abi on plc.abi_id = abi.id order by processed_date desc nulls last;' >> $sql

# run the SQL
psql -f $sql >> $data

# if all good, echo the data & remove the files. If not, leave the files.
# the output of this script will be saved and an error flagged
if [ $? == 0 ]
then
  cat $data
  rm $data $sql
else
  # raise an error, somewhere, somehow
  $LOGGER -t $0[$$] fatal error - see sql at $sql and output at $data
fi

$LOGGER -t $0[$$] finishes
