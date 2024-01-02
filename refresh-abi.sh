#!/bin/sh

# Ensure the ABI table contains the right list of values.

if [ ! -f config.sh ]
then
	echo "config.sh not found by missing-port-categories.sh..."
	exit 1
fi

. config.sh

valid=$(mktemp  ${SPOOLINGDIR}/abi-valid.XXXXXX)
delete=$(mktemp ${SPOOLINGDIR}/abi-delete.XXXXXX)
add=$(mktemp    ${SPOOLINGDIR}/abi-add.XXXXXX)

./current-list-of-valid-abi.sh > $valid
./delete-depcreated-abi.sh     > $delete
./add-new-abi.sh               > $add

rm $valid $delete $add
