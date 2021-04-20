#!/bin/sh
#
# This extracts the pkgmessage file for a given port for which the output of
# `make -V PKGMESSAGE` does not point to a file in the repo. In that case, we
# run `apply-slist` and see if that generates the file.
#
# sudo /usr/sbin/chroot -u USER JAIL /make-apply-slist.sh REPO_PATH PORT PKGMESSAGE
#
# where USER       - user as which to execute the commands.  e.g. dan
#       JAIL       - path to the jail created with the create-jail-directories.sh command. e.g. /usr/jail/FreshPorts
#       REPO_PATH  - path to the SVN repository e.g. /usr/local/PORTS-RELENG_9_1_0
#       PORT       - sysutils/bacula-server
#       PKGMESSAGE - the filename output by `make -V PKGMESSAGE` which does not exist in the repo
#

. ./vars.sh

REPO_PATH=$1
PORT=$2
PKGMESSAGE=$3

cd ${REPO_PATH}/${PORT}

mkdir work
${MAKE} apply-slist PORTSDIR=${REPO_PATH} OPTIONSFILE=${LOCALBASE} -f ${REPO_PATH}/${PORT}/Makefile > /dev/null
if [ $? == 0 ]
then
  if [ -r $PKGMESSAGE ]
  then
    cat $PKGMESSAGE
  fi
  ${MAKE} clean > /dev/null
fi
