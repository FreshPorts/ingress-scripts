#!/bin/sh

# THere are some scripts we want to run in series, when no commit processing is going on.
# For each of these, we set a flag and let job_waiting.pl take care of it.

# pull in the configuration...
. /usr/local/etc/freshports/config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

touch $CHECKPORTSCATEGORIESFILE

# fp-daemon runs job-waiting.pl only when this exists.  The job's own flag
# goes up first, so job-waiting.pl finds it when JOBWAITINGFLAG wakes it.
if [ -z "$JOBWAITINGFLAG" ]
then
	logger -p local3.err -t FreshPorts "$0: JOBWAITINGFLAG is not set in config.sh"
	exit 1
fi

touch $JOBWAITINGFLAG
