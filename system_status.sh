#!/bin/sh
#
# Copyright (c) 2001-2026 Dan Langille
#

#
# This script does not check for OFFLINE because it does not access the database
#

# for HTMLROOT, INGRESS_MSGDIR, MSGDIR, and VUXMLMUTEX
. /usr/local/etc/freshports/config.sh

# Temporary files go in HTMLROOT itself, not SPOOLINGDIR: they are separate
# ZFS filesystems, so a mv between them is a copy, and www could read a
# half-written file.  Within one filesystem, mv is an atomic rename.
SPOOL="${HTMLROOT}/.backend-status.html.$$.tmp"

# is commit processing enabled?
COMMITS=$(/usr/sbin/service ingress status)
PROCESSING=$(/usr/sbin/service freshports status)

# count of messages in the incoming queue
COUNT=$(/bin/ls ${INGRESS_MSGDIR}/incoming/ | /usr/bin/wc -l)

PROCESSED=$(/bin/ls ${MSGDIR}/recent/ | /usr/bin/grep -c xml)

echo '<p>Number of queued commits:   '  $COUNT       '</p>' >> ${SPOOL}
echo '<p>Commits processed today:    '  $PROCESSED   '</p>' >> ${SPOOL}
echo '<p>git commit checking status: '  $COMMITS     '</p>' >> ${SPOOL}
echo '<p>xml processing status:      '  $PROCESSING  '</p>' >> ${SPOOL}

# process_vuxml.sh holds VUXMLMUTEX while it runs; its mtime is when processing started
if [ -n "${VUXMLMUTEX}" -a -f "${VUXMLMUTEX}" ]
then
	VUXMLSTARTED=$(TZ=UTC /usr/bin/stat -f %Sm -t '%Y-%m-%d %H:%M:%S%z' ${VUXMLMUTEX})
	VUXMLELAPSED=$(( $(/bin/date +%s) - $(/usr/bin/stat -f %m ${VUXMLMUTEX}) ))
	VUXMLHOURS=$(( VUXMLELAPSED / 3600 ))
	VUXMLMINUTES=$(( VUXMLELAPSED % 3600 / 60 ))
	echo '<p class="in-progress">vuxml processing status: in progress since' $VUXMLSTARTED "(${VUXMLHOURS} hours ${VUXMLMINUTES} minutes)" '</p>' >> ${SPOOL}
else
	echo '<p>vuxml processing status:    not in progress</p>' >> ${SPOOL}
fi

/bin/mv ${SPOOL} ${HTMLROOT}/backend-status.html

#
# The versions of the ingress code and its packages, one "name version" per line;
# a git checkout adds its branch: "name version branch".
# www shows them as HTML comments on /other-copyrights.php, where the
# all-hosts versions page reads them.
#
VERSIONS="${HTMLROOT}/.ingress-versions.txt.$$.tmp"

# A git checkout (dev, dvl) reports git describe; its package is only a
# 9999 placeholder.  Anywhere else, report the package version.
# The checkout belongs to someone else, so git needs safe.directory.
#
# A git checkout also reports the branch it is on, as a third field, so the
# versions page can show which branch dvl and dev are testing.  A detached
# HEAD has no branch and gets no third field, nor does a package install,
# so on a package host every line keeps the "name version" form.
#
#   $1 = name to report, $2 = directory, $3 = package which installs it
ingress_version() {
	BRANCH=
	if [ -d "$2/.git" ]
	then
		VERSION=$(/usr/local/bin/git -c safe.directory="$2" -C "$2" describe --tags --always 2>/dev/null)
		BRANCH=$(/usr/local/bin/git -c safe.directory="$2" -C "$2" symbolic-ref --short -q HEAD 2>/dev/null)
	else
		VERSION=$(/usr/sbin/pkg query %v "$3" 2>/dev/null)
	fi
	echo "$1 ${VERSION:-unknown}${BRANCH:+ ${BRANCH}}"
}

ingress_version ingress-scripts /usr/local/libexec/freshports          p5-freshports-ingress-scripts >> ${VERSIONS}
ingress_version ingress-modules /usr/local/lib/perl5/site_perl/FreshPorts p5-freshports-ingress-modules >> ${VERSIONS}

# every other FreshPorts package; the two above are already reported.
# Pick them by origin (the freshports/ category of the FreshPorts ports
# tree), not by name: py314-packages-import has no "freshports" in its
# name, so matching names left it off the versions page.
/usr/sbin/pkg query '%o %n %v' | \
	/usr/bin/awk '$1 ~ /^freshports\// { print $2, $3 }' | \
	/usr/bin/grep -v -e '^p5-freshports-ingress-scripts ' -e '^p5-freshports-ingress-modules ' >> ${VERSIONS}

# Replace the file only when a version changes: www uses its mtime for
# Last-Modified, so rewriting it every run would defeat conditional GETs.
if /usr/bin/cmp -s ${VERSIONS} ${HTMLROOT}/ingress-versions.txt
then
	/bin/rm ${VERSIONS}
else
	/bin/mv ${VERSIONS} ${HTMLROOT}/ingress-versions.txt
fi
