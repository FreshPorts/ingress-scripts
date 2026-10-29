#!/bin/sh

#
# sometimes you need to find the raw text of the commit for the email
# this script does that.
#
# for more information: https://docs.freshports.org
#

hash=$1
echo $hash

# pull in the configuration...
. /usr/local/etc/freshports/config.sh

# check in recent dir
echo checking in recent dir
msg_subdir="recent"

file=`ls $MSGDIR/$msg_subdir/*.$hash.xml`
if [ $? == 0 ]
then
  echo found commit in $file
else
  echo nothing found: $file
fi
