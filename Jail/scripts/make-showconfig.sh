#!/bin/sh
#
# This extracts the config options for a given port.
#
# sudo /usr/sbin/jexec JAIL /make-showconfig.sh PORTDIR
#
# where JAIL      - name of the jail
#       REPO_PATH - path to the SVN repository, usually /usr/ports
#       PORTDIR   - sysutils/bacula-server
#

. ./vars.sh

REPO_PATH=$1
PORT=$2

cd ${REPO_PATH}/${PORT}

${MAKE} showconfig PORTSDIR=${REPO_PATH} OPTIONSFILE=${LOCALBASE} -f ${REPO_PATH}/${PORT}/Makefile
