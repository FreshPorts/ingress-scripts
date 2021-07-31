#!/bin/sh
#
# Sometimes the pkg-message file is in the ports tree, but is not ready for
# public consumption until after `make configure`. For example, files/pkg-message-in
#
# This extracts the pkgmessage file for a given port for which the output of
# `make -V PKGMESSAGE` does not point to a file in the repo. In that case, we
# run `make configure` and see if that generates the file.
#
# sudo /usr/sbin/chroot -u USER JAIL /make-pkg-message-in.sh REPO_PATH PORT PKGMESSAGE
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

${MAKE} make configure -DNO_DIALOG  PORTSDIR=${REPO_PATH} OPTIONSFILE=${LOCALBASE} -f ${REPO_PATH}/${PORT}/Makefile > /dev/null
if [ $? == 0 ]
then
  if [ -r $PKGMESSAGE ]
  then
    cat $PKGMESSAGE
  fi
  ${MAKE} clean > /dev/null
fi

# clean, and also remove the options file.
# [root@mydev:/usr/ports/x11/nvidia-hybrid-graphics] # make -V OPTIONS_FILE 
# /var/db/ports/x11_nvidia-hybrid-graphics/options
#

${MAKE} clean    > /dev/null
