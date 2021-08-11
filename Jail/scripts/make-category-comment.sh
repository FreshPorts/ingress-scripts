#!/bin/sh
#
# This extracts the COMMENT, or category description, from a Category Makefile
#
# expected usage: sudo /usr/sbin/jexec JAIL /make-category-comment.sh REPO_PATH CATEGORYDIR
#
# where JAIL      - name of the jail
#       REPO_PATH - path to the SVN repository, usually /usr/ports
#       CATEGORY  - sysutils
#

. ./vars.sh


REPO_PATH=$1
CATEGORY=$2

cd ${REPO_PATH}/${CATEGORY}

${MAKE} -V COMMENT -f ${REPO_PATH}/${CATEGORY}/Makefile
