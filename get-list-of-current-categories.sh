#!/bin/sh

# Based upon discussion in EFNET #bsdports channel on 2021-04-20
# contributors include: mat _0mp
#
# example output:
#
# [dan@devgit-ingress01:/var/db/ingress/repos/ports] $ find -s -f * -type d -regex '[a-z].*' -maxdepth 0 | xargs
# accessibility arabic archivers astro audio base benchmarks biology cad chinese comms converters databases 
# deskutils devel dns editors emulators finance french ftp games german graphics hebrew hungarian irc japanese
# java korean lang mail math misc multimedia net net-im net-mgmt net-p2p news polish ports-mgmt portuguese print
# russian science security shells sysutils textproc ukrainian vietnamese www x11 x11-clocks x11-drivers x11-fm 
# x11-fonts x11-servers x11-themes x11-toolkits x11-wm
#
# $ find -s -f * -type d -regex '[a-z].*' -maxdepth 0 | xargs | wc -w
#       62
#
# compare against:
# freshports.devgit=# select count(*) from categories where is_primary;
#  count 
# -------
#     67
# (1 row)
# 
#
# The plan: with each commit, get a list of the current categories. At one time, the number of special directories
# in the top level of the repo was manageable. With the recent addition of the .hooks directory, this issue came to
# light. FreshPorts assumes .hooks is a category. This will avoid that.
# We will load this up at run time, and have it.
#

CONFIG='/usr/local/etc/freshports/config.sh'

if [ ! -f ${CONFIG} ]
then
	echo "${CONFIG} not found by $0..."
	exit 1
fi

. ${CONFIG}

if [ $OFFLINE = 1 ]
then
	exit 0
fi

cd ${FRESHPORTS_JAIL_BASE_DIR}/${PORTSDIR}
/usr/bin/find -s -f * -type d -regex '[a-z].*' -maxdepth 0 | /usr/bin/xargs
