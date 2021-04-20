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

# the exec strips the leading ./ from the filename
# the sort, sorts
# the tr converts newlines to spaces
# the awk will trim leading and trailing space or tab characters and also squeeze sequences of tabs and spaces into a single space.
# https://unix.stackexchange.com/questions/102008/how-do-i-trim-leading-and-trailing-whitespace-from-each-line-of-some-output

find . -regex '.*/[a-z].*' -maxdepth 1 -exec sh -c "echo {} | sed 's|^\./||'" \; | sort | tr '\n' ' ' | awk '{$1=$1};1'
