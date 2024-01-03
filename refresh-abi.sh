#!/bin/sh

# Ensure the ABI table contains the right list of values.

if [ ! -f config.sh ]
then
	echo "config.sh not found by missing-port-categories.sh..."
	exit 1
fi

. config.sh

export PGDATABASE=$DB
export PGHOST=$HOST
export PGUSER=$DBUSER_ABI

# see also PGSSLMODE and PGSSLROOTCERT in config.sh


valid=$(mktemp  ${SPOOLINGDIR}/abi-valid.XXXXXX)
sql=$(mktemp ${SPOOLINGDIR}/abi-sel.XXXXXX)

# fetch and extract the list of valid ABI
./current-list-of-valid-abi.sh > $valid

# build the SQL commands
echo 'BEGIN;'                           >  $sql

# ABI to be deleted
./delete-depcreated-abi.sh     < $valid >> $sql

# ABI to be added
echo                                    >> $sql
./add-new-abi.sh               < $valid >> $sql

# and we end
echo                                    >> $sql
echo 'ROLLBACK;'                          >>  $sql

# run the SQL
psql -f $sql 


# if all good, remove the files. If not, leave the files
# the output of this script will be saved and an error flagged
if [ $? == 0 ]
then
  # commit taken
  rm $valid $sql
else
  # raise an error, somewhere, somehow
fi
