#!/bin/sh

# remember to turn off the freshports service before running this script
#
#  sudo service freshports stop

ROWS=838
LIMIT=40

OFFSETS=$(seq 0 1000 30000)
OFFSETS=$(seq 0 33   1007)
OFFSETS=$(seq 0 $LIMIT $ROWS)

cd /usr/local/libexec/freshports
for offset in ${OFFSETS}
do
	sudo -u freshports sh -c "perl refresh-ports.pl --limit=$LIMIT --offset=${offset} > /var/log/freshports/refreshing.$offset.log" &
done
