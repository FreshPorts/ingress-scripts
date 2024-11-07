#!/bin/sh

# This scripts invokes the chroot for freshports and works off the Makefile
# see also test-master-port.pl which queries the database.

if [ ! -f config.sh ]
then
	echo "config.sh not found by $0"
	exit 1
fi

. config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

MASTER='sysutils/bacula15-server'

# this always tests against head
COMMAND="/usr/local/bin/sudo /usr/sbin/jexec ${FRESHPORTS_JAIL_NAME} ${FRESHPORTS_JAIL_MASTER_PORT_SCRIPT} ${PORTSDIR} sysutils/bacula15-client"
MASTER_PORT=$(${COMMAND})

if [ "${MASTER_PORT}X" != "${MASTER}X" ]
then
	echo "make -V MASTER_PORT on sysutils/bacula15-client does not give '${MASTER}'\nInstead, it gives '${MASTER_PORT}'." | mail -s "FAILED: MASTER_PORT" ${ADMINEMAIL}
fi
