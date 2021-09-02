#!/bin/sh
#
# Sometimes the pkg-message file is in the ports tree, but is not ready for
# public consumption until after `make apply-slist`. For example, files/pkg-message-in
# There is no need to invoke this function if `make -V PKGMESSAGE` exists.
#
# This extracts the pkgmessage file for a given port for which the output of
# `make -V PKGMESSAGE` does not point to a file in the repo. In that case, we
# run `make apply-slist` and see if that generates the file.
#
# sudo /usr/sbin/jexec JAIL /make-pkg-message-in.sh REPO_PATH PORT PKGMESSAGE
#
# where JAIL       - name of the jail
#       REPO_PATH  - path to the SVN repository, usually /usr/ports
#       PORT       - sysutils/bacula-server
#       PKGMESSAGE - the filename output by `make -V PKGMESSAGE` which does not exist in the repo
#

. ./vars.sh

REPO_PATH=$1
PORT=$2
PKGMESSAGE=$3

cd ${REPO_PATH}/${PORT}

${MAKE} extract apply-slist -DNO_DIALOG > /dev/null 2>&1
if [ $? == 0 ]
then
  if [ -r $PKGMESSAGE ]
  then
    cat $PKGMESSAGE
  fi
fi

# clean, remove the distfiles, and also remove the options files.
# [root@mydev:/usr/ports/x11/nvidia-hybrid-graphics] # make -V OPTIONS_FILE 
# /var/db/ports/x11_nvidia-hybrid-graphics/options
#

${MAKE} clean rmconfig-recursive > /dev/null 2>&1
