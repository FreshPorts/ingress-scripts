#!/bin/sh
#
# $Id: svn-up-file.sh,v 1.1 2012-08-15 11:49:10 dan Exp $
#
# Copyright (c) 1999-2019 Dan Langille
#
# This script used to checkout a given commit via a git working copy

echo "num of params = $#"
if  [ $# -ne 2 ];
then echo error invoking script $0 : usage $0 GITDIR REVISION \(e.g. $0 /usr/ports 1234\)
  exit 1
else
    GITDIR=$1
    REVISION=$2

    # we may not need this cd...
    cd ${GITDIR}
    
    # we need to a do a /usr/local/bin/git fetch
    # we may not have this commit
    echo /usr/local/bin/git fetch
    /usr/local/bin/git fetch
    echo "/usr/local/bin/git checkout ${REVISION}"
    /usr/local/bin/git checkout ${REVISION}
    exit $?
fi
