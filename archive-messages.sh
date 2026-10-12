#!/bin/sh
#
# $Id: archive-messages.sh,v 1.2 2006-12-17 12:03:59 dan Exp $
#
# Copyright (c) 2003-2026 Dan Langille
#
# archive away all the messages which were created yesterday.
# this script is designed to be called like this from crontab:
#
#  10  0   *   *   *  cd $DIR && ./archive-messages.sh 1 >> /dev/null
#
# where $DIR is the directory in which this file exists.
#
# cleanup mode archives every message in recent/ which does not have
# today's date in its name, each into the archive directory for its own
# date.  Use it to catch up after missed runs:
#
#  cd $DIR && ./archive-messages.sh cleanup
#
# add -n to cleanup for a dry run: list what would be moved, move nothing.
#
#  cd $DIR && ./archive-messages.sh cleanup -n
#
# message names start with the date, e.g. 2026.10.11.12.34.56.12345.txt.xml

usage() {
	echo "usage: $0 DAYS | cleanup [-n]"
	exit 1
}

DRYRUN=0

if [ "$1" = cleanup ] && [ $# -eq 2 ]
then
	if [ "$2" != -n ]
	then
		usage
	fi
	DRYRUN=1
elif [ $# -ne 1 ]
then
	usage
fi

if [ ! -f config.sh ]
then
	echo "config.sh not found by archive-messages.sh..."
	exit 1
fi

. ./config.sh

if [ "$OFFLINE" = 1 ]
then
	exit 0
fi

RECENT="${MSGDIR}/recent"

# archive_day YYYY.MM.DD
# move all messages in recent/ for that day to archive/YYYY_MM/YYYY_MM_DD/
archive_day() {
	YYYYMMDD=$1
	YYYY_MM_DD=$(echo "${YYYYMMDD}" | tr . _)
	YYYY_MM=${YYYY_MM_DD%_*}

	DEST="${MSGDIR}/archive/${YYYY_MM}/${YYYY_MM_DD}/"

	if [ "${DRYRUN}" = 1 ]
	then
		find "${RECENT}" -maxdepth 1 -type f -name "${YYYYMMDD}*" -exec echo "would move {} to ${DEST}" \;
		return
	fi

	mkdir -p "${DEST}" || exit 1

	# the -maxdepth 1 is so I can mkdir erorrs && mv stuff errors and keep them around
	find "${RECENT}" -maxdepth 1 -type f -name "${YYYYMMDD}*" -print0 | xargs -0 -J % mv % "${DEST}"
}

case "$1" in
cleanup)
	TODAY=$(date "+%Y.%m.%d")

	find "${RECENT}" -maxdepth 1 -type f \
		-name '[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]*' ! -name "${TODAY}*" \
		| sed -e 's|.*/||' | cut -c1-10 | sort -u | \
	while read -r DAY
	do
		echo "archiving ${DAY}"
		archive_day "${DAY}"
	done
	;;

*[!0-9]*|'')
	usage
	;;

*)
	archive_day "$(date -v-"$1"d "+%Y.%m.%d")"
	;;
esac
