#!/bin/sh

# I noticed a new user with AI in their login id.
# Are they creating a login to bypass various restrictions?
# Let's see

. /usr/local/etc/freshports/config.sh

if [ $OFFLINE = 1 ]
then
	exit 0
fi

#
# save these values for use by psql via environment variables. The password is stored in ~/.pgpass
#
export PGDATABASE=$DB
export PGHOST=$HOST
export PGUSER=$DBUSER

TO_EMAIL="${ADMINEMAIL}"
SUBJECT="FreshPorts -- most active users"


SPOOL_FILE=$(mktemp ${SPOOLINGDIR}/most-active-users.XXXXXX)

# use 'sslcertmode=disable' to avoid: could not open certificate file "/root/.postgresql/postgresql.crt": Permission denied

psql --output=${SPOOL_FILE} "sslcertmode=disable" <<EOF
select U.id, U.name, U.firstlogin, count(*)
  from users U join page_load_detail PLD
          on U.id = PLD.user_id
group by U.id
order by count DESC
limit 40
EOF

if [ $? -ne 0 ]
then
	logger -p local3.error -t FreshPorts $0 errored when running psql - FATAL
	rm ${SPOOL_FILE}
	exit 1
fi

# this is for the logs (/var/log/daily.log)
cat ${SPOOL_FILE}

# this is for the email so I don't have to look at the logs
cat ${SPOOL_FILE} | mail -s "$SUBJECT" "$TO_EMAIL"

rm ${SPOOL_FILE}
logger -p local3.notice -t FreshPorts $0 has completed.
