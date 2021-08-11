#!/bin/sh
#
# This extracts the config options for a given port.
#
# sudo /usr/sbin/jexec JAIL /make-generate-plist.sh REPO_PATH PORT
#
# where JAIL      - name of the jail
#       REPO_PATH - path to the SVN repository, usually /usr/ports
#       PORT      - sysutils/bacula-server
#

. ./vars.sh

REPO_PATH=$1
PORT=$2

cd ${REPO_PATH}/${PORT}

${MAKE} generate-plist PORTSDIR=${REPO_PATH} OPTIONSFILE=${LOCALBASE} -f ${REPO_PATH}/${PORT}/Makefile > /dev/null
if [ $? == 0 ]
then
  cat work/.PLIST.mktmp
  ${MAKE} clean > /dev/null
fi