#!/bin/sh
#
# $Id: searchlog.sh,v 1.4 2006-12-17 12:04:03 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#

grep $(date -v-1d "+%Y-%m-%d") ${CACHINGROOT}/searchlog.txt
