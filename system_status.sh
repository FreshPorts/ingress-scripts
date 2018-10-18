#!/bin/sh
#
# Copyright (c) 2001-2006 DVL Software
#


SPOOL="/var/db/freshports/cache/spooling/$0.$$.tmp"

# is commit processing enabled?
COMMITS=`/usr/local/bin/sudo /usr/local/bin/svstat /var/service/freshports`

# count of messages in the incoming queue
COUNT=`/bin/ls /var/db/ingress/message-queues/incoming/ | /usr/bin/wc -l`

echo '<p>Number of queued commits: '   $COUNT    '</p>' >> ${SPOOL}
echo '<p>Commit processing status: '  $COMMITS  '</p>' >> ${SPOOL}

/bin/mv ${SPOOL} /var/db/freshports/cache/html/backend-status.html
