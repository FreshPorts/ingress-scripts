#!/bin/sh

# Refresh the ports compare-index.sh found to be out of date.
#
# job-waiting.pl runs this when $FreshPorts::Config::RefreshFromIndexFlag
# exists, with no arguments, so the list is fixed here rather than passed in:
# it is the refresh.txt compare-index.sh wrote.
#
# compare-index-daily.sh raises that flag, and only when refresh.txt has
# something in it, so an empty run should not reach here at all.
#
# config.sh is sourced by absolute path because job-waiting.pl runs this with
# whatever working directory it happens to have.

. /usr/local/etc/freshports/config.sh

#
# The flag goes first.  job-waiting.pl loops until every flag is gone and
# complains after five passes, so a script which leaves its own flag behind
# looks like a job which is stuck.
#
rm -f ${REFRESHFROMINDEXFLAG}

logger -p local3.notice -t FreshPorts $0 has started.

if [ $OFFLINE = 1 ]
then
	logger -p local3.notice -t FreshPorts $0 exits because system is offline
	exit 0
fi

#
# compare-index.sh writes its lists to SPOOLINGDIR unless told otherwise,
# and compare-index-daily.sh does not tell it otherwise.
#
LIST="${SPOOLINGDIR}/refresh.txt"

if [ ! -s $LIST ]
then
	logger -p local3.notice -t FreshPorts $0 found nothing to do in $LIST
	exit 0
fi

logger -p local3.notice -t FreshPorts $0 refreshing $(wc -l < $LIST | tr -d ' ') ports from $LIST

${SCRIPTDIR}/refresh-listed-ports.pl $LIST
RESULT=$?

logger -p local3.notice -t FreshPorts $0 has completed, refresh-listed-ports.pl exited $RESULT

exit $RESULT
