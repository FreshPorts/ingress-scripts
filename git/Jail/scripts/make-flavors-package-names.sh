#!/bin/sh
#
# This extracts information from a port Makefile regarding packages and flavors
#
# expected usage: sudo /usr/sbin/jexec JAIL /make-flavors-package-names.sh REPO_PATH PORTDIR
#
# where JAIL      - name of the jail
#       REPO_PATH - path to the SVN repository, usually /usr/ports
#       PORT      - sysutils/bacula-server
#

. ./vars.sh

REPO_PATH=$1
PORT=$2

cd ${REPO_PATH}/${PORT}

FLAVORS=`${MAKE} -V FLAVORS -f ${REPO_PATH}/${PORT}/Makefile PORTSDIR=${REPO_PATH}`
for flavor in ${FLAVORS}
do
  PKGBASE=`${MAKE} make -V FLAVOR -V PKGBASE FLAVOR=${flavor} -f ${REPO_PATH}/${PORT}/Makefile PORTSDIR=${REPO_PATH}`
  if [ $? != 0 ]
  then
     return $?
  else
     echo ${PKGBASE}
  fi
done

return 0
