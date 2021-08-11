#!/bin/sh
#
# This extracts the master port for a given port.
#
# sudo /usr/sbin/jexec JAIL /make-master-sites-all.sh REPO_PATH PORTDIR
#
# where JAIL      - name of the jail
#       REPO_PATH - path to the SVN repository, usually /usr/ports
#       PORT      - sysutils/bacula-server
#

. ./vars.sh

REPO_PATH=$1
PORT=$2

cd ${REPO_PATH}/${PORT}

${MAKE} -V _MASTER_SITES_ALL PORTSDIR=${REPO_PATH} LOCALBASE=${LOCALBASE} -f ${REPO_PATH}/${PORT}/Makefile
