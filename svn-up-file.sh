#!/bin/sh
#
# $Id: svn-up-file.sh,v 1.1 2012-08-15 11:49:10 dan Exp $
#
# Copyright (c) 1999-2026 Dan Langille
#
# This script used to svn up files...

echo "num of params = $#"
if  [ $# -ne 3 ];
then echo error invoking script $0 : usage $0 SVNDIR SVNITEM REVISION \(e.g. $0 /usr/ports sysutils/bacula-server 1234\)
  exit 1
else
    SVNDIR=$1
    SVNITEM=$2
    REVISION=$3

    # we may not need this cd...
    echo cd to ${SVNDIR}
    cd ${SVNDIR}
    
    pwd
    echo "doing this: svn up -r ${REVISION} ${SVNITEM}"
    svn up -r ${REVISION} ${SVNITEM}
    exit $?
fi
