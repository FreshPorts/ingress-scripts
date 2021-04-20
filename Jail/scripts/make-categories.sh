#!/bin/sh
#
# Obtain the list of categories, based on what's in the base directory of the repo
#
# expected usage: sudo /usr/sbin/chroot -u USER JAIL /make-categories.sh REPO_PATH
#
# where USER      - user as which to execute the commands.  e.g. dan
#       JAIL      - path to the jail created with the create-jail-directories.sh command. e.g. /usr/jail/FreshPorts
#       REPO_PATH - path to the SVN repository e.g. /usr/local/PORTS-RELENG_9_1_0
#

. ./vars.sh

REPO_PATH=$1

cd ${REPO_PATH}

# -s to sort
# -f * in case we have a -foo file
# type -d because we want only directories

find -s -f * -type d -regex '[a-z].*' -maxdepth 0 | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g'
