#!/bin/sh
#
# This returns resolved physical path via realpath(3).
# We were using Cwd::abs_path, but in a jail we would get results such as /basejail/usr/ports/sysutils/bacula-server
# which is not ideal at all
#
# expected usage: sudo /usr/sbin/chroot -u USER JAIL /realpath.sh PATH_NAME
#
# where USER      - user as which to execute the commands.  e.g. dan
#       JAIL      - path to the jail created with the create-jail-directories.sh command. e.g. /usr/jail/FreshPorts
#       PATH_NAME - /usr/ports/sysutils/bacula-server/pkg-descr
#

. ./vars.sh

PATH_NAME=$1

/bin/realpath -q ${PATH_NAME}
