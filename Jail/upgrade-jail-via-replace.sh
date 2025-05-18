#!/bin/sh

# re https://news.freshports.org/2025/03/27/updating-a-jail-by-replacing-it/

# Exit early if there is an error
# re https://gist.github.com/BertanT/9d222da115ca2d1274ef34735c4260cf
#
set -e


service freshports stop
service ingress    stop

service jail       stop

zfs rename data02/freshports/jailed/dvl-ingress01/jails/freshports data02/freshports/jailed/dvl-ingress01/jails/freshports.14.2

mkjail create -v 14.2-RELEASE -j freshports -a amd64

./copy-scripts-into-jail.sh /jails/freshports

cp -i /jails/freshports.14.2/vars.sh /jails/freshports/

mkdir /jails/freshports/usr/ports

service jail start

# and here I stopped, because I was updating a jail (patching), not moving to a new release