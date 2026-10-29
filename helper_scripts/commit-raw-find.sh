#!/bin/sh

#
# sometimes you need to find the raw text of the commit for the email
# this script does that.
#
# for more information: https://docs.freshports.org
#

message_id=$1
echo $message_id

year=`echo $message_id | awk '{ print substr($1,1,4)}'`
month=`echo $message_id | awk '{ print substr($1,5,2)}'`
day=`echo $message_id | awk '{ print substr($1,7,2)}'`

echo $year, $month, $day

commit_date="$year$month$day"

yesterday=`date -v-1d +%Y%m%d`

echo "yesterday: $yesterday"
echo "commit:    $commit_date"

if [ $commit_date -gt $yesterday ]
then
  # check in recent dir
  echo checking in recent dir
  msg_subdir="recent"
else
  # check in archives
  echo checking in archives
  msg_subdir="archive/${year}_$month/${year}_${month}_$day"
fi

# pull in the configuration...
. /usr/local/etc/freshports/config.sh

# ... which defines:
echo $MSGDIR

file=`grep -l $message_id $MSGDIR/$msg_subdir/*.txt.raw`
if [ $? == 0 ]
then
  echo found commit in $file
else
  echo nothing found: $file
fi
