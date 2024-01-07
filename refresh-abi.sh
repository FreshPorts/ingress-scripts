#!/bin/sh

# Ensure the ABI table contains the right list of values.

if [ ! -f config.sh ]
then
	echo "config.sh not found by missing-port-categories.sh..."
	exit 1
fi

. config.sh

$LOGGER $0 starts

export PGDATABASE=$DB
export PGHOST=$HOST
export PGUSER=$DBUSER_ABI

# see also PGSSLMODE and PGSSLROOTCERT in config.sh


valid=$(mktemp ${SPOOLINGDIR}/abi-valid.XXXXXX)
sql=$(mktemp   ${SPOOLINGDIR}/abi-sql.XXXXXX)
log=$(mktemp   ${SPOOLINGDIR}/abi-log.XXXXXX)

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
echo 'COMMIT;'                          >> $sql

# run the SQL
psql -f $sql                            >> $log


# if all good, remove the files. If not, leave the files
# the output of this script will be saved and an error flagged
if [ $? == 0 ]
then
  # commit taken.
  # grep for non-zero results, which would look like this:
  #
  # BEGIN
  # DELETE 0
  # INSERT 0 0
  # COMMIT
  
  if [ "$(grep -c 'DELETE 0' $log)" != "1" ] || [ "$(grep -c 'INSERT 0 0' $log)" != "1" ]
  then
     # put this in the logs of the job we're running, probably /var/log/daily.log
     $LOGGER $(date)
     $LOGGER $(cat $log)

     # and to the logs on disk for later review
     echo $(date) >> ${ABILOG}
     cat ${log}   >> ${ABILOG}
  else
    $LOGGER $0 nothing to change
  fi
  
  rm $valid $sql $log
else
  # raise an error, somewhere, somehow
  $LOGGER $0 fatal error - see sql at $sql
fi

$LOGGER $0 finishes
