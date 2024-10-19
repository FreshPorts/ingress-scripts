#!/bin/sh
#
# Copyright (c) 2001-2021 DVL Software
#

#
# This script does not check for OFFLINE because it does not access the database
#

SPOOL="/var/db/freshports/cache/spooling/$0.$$.tmp"

# is commit processing enabled?
COMMITS=$(/usr/sbin/service ingress status)
PROCESSING=$(/usr/sbin/service freshports status)

# count of messages in the incoming queue
COUNT=$(/bin/ls /var/db/ingress/message-queues/incoming/ | /usr/bin/wc -l)

PROCESSED=$(/bin/ls /var/db/freshports/message-queues/recent/ | /usr/bin/grep -c xml)

echo '<p>Number of queued commits:   '  $COUNT       '</p>' >> ${SPOOL}
echo '<p>Commits processed today:    '  $PROCESSED   '</p>' >> ${SPOOL}
echo '<p>git commit checking status: '  $COMMITS     '</p>' >> ${SPOOL}
echo '<p>xml processing status:      '  $PROCESSING  '</p>' >> ${SPOOL}

/bin/mv ${SPOOL} /var/db/freshports/cache/html/backend-status.html
