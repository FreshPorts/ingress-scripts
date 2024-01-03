#!/bin/sh
#
# This scripts takes the website offline, or puts it back online,
# depending on what is required
#

. config.sh

# let the daemons, cronjobs etc know we are offline
#

CONFIGDIR="${SCRIPTDIR}/../configuration"

if [ "$1" = "stop" -o "$1" = "start" ]
then
	# correct parm
else
	echo "usage: $0 {start|stop}"
fi

if [ "$1" = "stop" ]
then
	touch ${SCRIPTDIR}/OFFLINE
	rm -f ${CONFIGDIR}/vhosts.conf
	ln -s ${CONFIGDIR}/vhosts.conf.offline ${CONFIGDIR}/vhosts.conf
	sudo apachectl graceful
	sudo svc -d /var/service/fp-listen
fi

if [ "$1" = "start" ]
then
	rm -f ${SCRIPTDIR}/OFFLINE
	rm -f ${CONFIGDIR}/vhosts.conf
	ln -s ${CONFIGDIR}/vhosts.conf.online ${CONFIGDIR}/vhosts.conf
	sudo apachectl graceful
	sudo svc -u /var/service/fp-listen
fi
