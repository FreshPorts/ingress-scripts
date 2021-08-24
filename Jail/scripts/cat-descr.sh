#!/bin/sh
#
# This extracts the contents of the given file, assuming it is a description file.  e.g. /usr/ports/sysutils/bacula-server/pkg-descr
#
# expected usage: sudo /usr/sbin/chroot -u USER JAIL /cat-descr.sh FULL_PATH_TO_FILE
#
# where USER              - user as which to execute the commands.  e.g. dan
#       JAIL              - path to the jail created with the create-jail-directories.sh command. e.g. /usr/jail/FreshPorts
#       FULL_PATH_TO_FILE - /usr/ports/sysutils/bacula-server/pkg-descr
#

. ./vars.sh

FULL_PATH_TO_FILE=$1

if [ -r ${FULL_PATH_TO_FILE} ]
then
  /bin/cat ${FULL_PATH_TO_FILE}
fi

