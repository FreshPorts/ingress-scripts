#!/bin/sh
#
# $Id: newusers.sh,v 1.3 2006-12-17 12:04:01 dan Exp $
#
# Copyright (c) 2001-2003 DVL Software
#
/usr/local/bin/perl newusers.pl $(date -v-1d "+%Y-%m-%d") $(date -v-1d "+%Y-%m-%d")
