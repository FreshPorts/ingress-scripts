#!/bin/sh
#
# This extracts the master port for a given port.
#
# sudo /usr/sbin/jexec JAIL /make-master-port-test.sh REPO_PATH PORTDIR
#
# where JAIL      - name of the jail
#       REPO_PATH - path to the SVN repository, usually /usr/ports
#       PORT      - sysutils/bacula-server
#

. ./vars.sh

REPO_PATH=$1
PORT=$2

cd ${REPO_PATH}/${PORT}

${MAKE} -V MASTER_PORT -f ${REPO_PATH}/${PORT}/Makefile PORTSDIR=${REPO_PATH} LOCALBASE=${LOCALBASE} X11BASE=${X11BASE}
