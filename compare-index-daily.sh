#!/bin/sh

# Compare the ports INDEX with the database, once a day, and mail the result.
#
# The INDEX is built at the commit FreshPorts has finished processing, so the
# two sides describe the same tree.  Without that the comparison reports ports
# which moved between the two moments, which is not drift.
#
# Runs as the freshports user, named in the entry, so this goes in a crontab
# which has a user field -- /etc/crontab or a file under cron.d -- rather
# than in a user's own.  02:04 UTC:
#
#   CRON_TZ=UTC
#   4 2 * * * freshports /usr/local/libexec/freshports/compare-index-daily.sh
#
# CRON_TZ because 02:04 was asked for in UTC; without it cron uses the
# machine's own time.
#
# Nothing here needs arguments.  compare-index.sh does the work; this finds
# the commit, hands it over, and mails what comes back.

. /usr/local/etc/freshports/config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

logger -p local3.notice -t FreshPorts $0 has started.

TO_EMAIL="${ADMINEMAIL}"
SUBJECT="FreshPorts -- compare-index"

SPOOL_FILE=$(mktemp ${SPOOLINGDIR}/compare-index-daily.XXXXXX) || exit 1

trap "rm -f $SPOOL_FILE" EXIT INT TERM

#
# The last commit FreshPorts has processed on main.  git-delta.sh tags it,
# but only once git-to-freshports-xml.py has returned 0 for the batch:
#
#   git tag -m "last known commit of origin/main" -f freshports/origin/main origin/main
#
# so the tag is the ingress saying how far it has got, which is exactly the
# commit the INDEX should be built at.  The repo is asked rather than the
# database: the tag is on main by construction, it cannot name a src or doc
# commit, and it does not move part way through a batch.
#
# origin and main are spelled out here because git-delta.sh spells them out
# too, in REMOTE and NAME_OF_HEAD.
#
# ^{} dereferences the annotated tag down to the commit it points at.
# Without it this returns the hash of the tag object, which is not a commit
# and would not check out.  git-delta.sh uses the same suffix where it works
# out STARTPOINT.
#
# That repo belongs to the ingress user and this runs as freshports, so git
# refuses it as dubious ownership and returns nothing.  The exception is
# given here, for this one path and this one command, rather than with
# 'git config --global --add safe.directory' in the freshports user's own
# config: it stays with the script, it is visible to whoever reads it, and
# it does not survive as host state after the script is gone.  Reading a
# ref is all we do with it.
#
PORTS_REPO="${INGRESS_PORTS_DIR_BASE}/$(convert_repo_label_to_directory ports)"
FRESHPORTS_TAG="freshports/origin/main"

COMMIT=$($GIT -c safe.directory=$PORTS_REPO -C $PORTS_REPO rev-parse -q --verify ${FRESHPORTS_TAG}^{})

if [ "${COMMIT}x" = 'x' ]
then
	logger -p local3.error -t FreshPorts $0 found no $FRESHPORTS_TAG in $PORTS_REPO
	echo "$0: no $FRESHPORTS_TAG in $PORTS_REPO -- has git-delta.sh ever completed a batch?" |
		mail -s "$SUBJECT -- no commit found" "$TO_EMAIL"
	exit 1
fi

logger -p local3.notice -t FreshPorts $0 comparing at $COMMIT

#
# compare-index.sh reads config.sh from the current directory, so it has to
# be run from where it lives.
#
cd ${SCRIPTDIR} || exit 1

./compare-index.sh -b -c $COMMIT > ${SPOOL_FILE} 2>&1
RESULT=$?

if [ $RESULT = 0 ]
then
	SUBJECT="$SUBJECT -- $COMMIT"

	#
	# Tell watchgoose the run finished.  On success only: a ping after a
	# failed run would report the check as healthy when it is not, which is
	# worse than no monitoring at all.
	#
	# The URL carries a token, so it lives in config.sh rather than here.
	# Empty means do not ping, which keeps this quiet on a host which is not
	# being watched.
	#
	if [ "${WATCHGOOSE_COMPARE_INDEX}x" != 'x' ]
	then
		$FETCH --output /dev/null -q --retry --retry-delay=10 "$WATCHGOOSE_COMPARE_INDEX"
	fi
else
	SUBJECT="$SUBJECT -- FAILED at $COMMIT"
fi

#
# Mailed whether it worked or not: a silent failure at 02:04 is one nobody
# finds until the lists go stale.
#
# make index names every category as it goes, sixty-odd lines of
# '--- describe.foo ---' around the five lines anyone reads.  They are left
# in the spool file, which is what the log wants, and taken out of the mail.
# Removing the markers rather than whole lines because the first and last are
# run together with the text either side of them.
#
sed -e 's/--- describe\.[^ ]* ---//g' -e '/^[[:space:]]*$/d' ${SPOOL_FILE} |
	mail -s "$SUBJECT" "$TO_EMAIL"

logger -p local3.notice -t FreshPorts $0 has completed.

exit $RESULT
