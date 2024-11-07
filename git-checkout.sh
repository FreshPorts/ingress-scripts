#!/bin/sh
#
# $Id: svn-up-file.sh,v 1.1 2012-08-15 11:49:10 dan Exp $
#
# Copyright (c) 1999-2019 Dan Langille
#
# This script used to checkout a given commit via a git working copy

if [ ! -f config.sh ]
then
	echo "config.sh not found by $0..."
	exit 1
fi

. config.sh

echo "num of params = $#"
if  [ $# -ne 2 ];
then echo error invoking script $0 : usage $0 GITDIR REVISION \(e.g. $0 /usr/ports 1234\)
  exit 1
else
    GITDIR=$1
    REVISION=$2

    # we may not need this cd...
    cd ${GITDIR}
    
    # we need to a do a git fetch
    # we may not have this commit
    echo ${GIT} fetch
    ${GIT} fetch
    echo "${GIT} checkout ${REVISION}"
    ${GIT} checkout ${REVISION}
    exit $?
fi
