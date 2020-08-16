
#!/bin/sh
#
# This extracts the config options for a given port.
#
# sudo /usr/sbin/chroot -u USER JAIL /make-generate-plist.sh REPO_PATH PORT
#
# where USER      - user as which to execute the commands.  e.g. dan
#       JAIL      - path to the jail created with the create-jail-directories.sh command. e.g. /usr/jail/FreshPorts
#       REPO_PATH - path to the SVN repository e.g. /usr/local/PORTS-RELENG_9_1_0
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
