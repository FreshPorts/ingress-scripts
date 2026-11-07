#!/bin/sh
#
# Copyright (c) 2026 Dan Langille
#
# Fetch portscout's list of ports and the newer versions it has found
# upstream, and load it into port_upstream with portscout_upstream.pl,
# for the port page (#626).
#
# Run daily, as freshports, from periodic daily/236.fp_portscout_upstream.
# By hand:
#
#   cd /usr/local/libexec/freshports && ./portscout_upstream.sh
#
# The URL is PORTSCOUT_URL in config.sh, not here.  Empty means do nothing,
# which keeps this quiet on a host where it has not been set up.
#
# The last copy which loaded is kept as ${SPOOLINGDIR}/portscout.json.
# fetch -i asks for the file only if it has changed since that copy was
# made; fetch gives the copy the server's Last-Modified time, which is what
# -i sends back.  A new copy goes to a dotfile beside it, and replaces it
# only once portscout_upstream.pl has accepted and loaded it.
#
# The load runs even when nothing new was fetched: our own versions change
# between runs, and a port updated since yesterday has to drop out.
#

. /usr/local/etc/freshports/config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

LOGGERTAG="portscout_upstream.sh"

if [ "${PORTSCOUT_URL}x" = 'x' ]
then
	${LOGGER} -t ${LOGGERTAG} "PORTSCOUT_URL is not set in config.sh: nothing to do"
	exit 0
fi

CURRENT="${SPOOLINGDIR}/portscout.json"
NEW="${SPOOLINGDIR}/.portscout.json.new"

#
# The server often closes the connection part way through: in November
# 2026, after about 200 KB of 9 MB, most of the time.  fetch says the file
# "appears to be truncated", exits non-zero, and leaves what it got.  -r
# carries on from there, so keep asking until it has the lot, up to
# PORTSCOUT_FETCH_TRIES times in all; 26 tries were needed in testing.
#
# fetch checks what it got against Content-Length, so a zero exit means
# the whole file.  Should the file change between tries, the pieces will
# not make valid JSON and portscout_upstream.pl will refuse it.
#
PORTSCOUT_FETCH_TRIES=${PORTSCOUT_FETCH_TRIES:-60}

rm -f "$NEW"

if [ -s "$CURRENT" ]
then
	$FETCH -q -i "$CURRENT" -o "$NEW" "$PORTSCOUT_URL" 2>/dev/null
else
	$FETCH -q -o "$NEW" "$PORTSCOUT_URL" 2>/dev/null
fi
FETCHED=$?
TRIES=1

while [ $FETCHED -ne 0 -a -s "$NEW" -a $TRIES -lt $PORTSCOUT_FETCH_TRIES ]
do
	$FETCH -q -r -o "$NEW" "$PORTSCOUT_URL" 2>/dev/null
	FETCHED=$?
	TRIES=$((TRIES + 1))
done

#
# What is left of a transfer which never finished is not a copy anyone
# should load.
#
if [ $FETCHED -ne 0 ]
then
	${LOGGER} -t ${LOGGERTAG} "fetch failed with $FETCHED after $TRIES tries; using the copy from the last run, if any"
	rm -f "$NEW"
elif [ -s "$NEW" ]
then
	${LOGGER} -t ${LOGGERTAG} "fetched in $TRIES tries"
fi

if [ -s "$NEW" ]
then
	FILE="$NEW"
elif [ -s "$CURRENT" ]
then
	FILE="$CURRENT"
	${LOGGER} -t ${LOGGERTAG} "no new copy; loading the one from the last run"
else
	${LOGGER} -t ${LOGGERTAG} "FATAL no copy of the portscout data to load"
	exit 1
fi

#
# portscout_upstream.pl finds FreshPorts::config the same way the other
# scripts do, from where it lives.
#
cd ${SCRIPTDIR} || exit 1

/usr/local/bin/perl ./portscout_upstream.pl --filename="$FILE"
RESULT=$?

if [ $RESULT -eq 0 ]
then
	if [ "$FILE" = "$NEW" ]
	then
		mv -f "$NEW" "$CURRENT"
	fi
else
	${LOGGER} -t ${LOGGERTAG} "FATAL portscout_upstream.pl failed with $RESULT; port_upstream is unchanged"
fi

rm -f "$NEW"

#
# A failed fetch still loaded yesterday's copy, but say so in the exit
# status, so periodic reports it.
#
if [ $RESULT -eq 0 -a $FETCHED -ne 0 ]
then
	RESULT=1
fi

exit $RESULT
