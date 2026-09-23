#!/bin/sh
#
# Compare the package versions in the ports INDEX with the ones FreshPorts
# holds, and write out the list of ports which need refreshing.
#
# A port's version can change without a commit to its own directory: a master
# port moves, or an included Makefile does.  Nothing tells the ingress to
# refresh those ports, so they sit in the database at an old version.  This
# finds them by comparing every port against the INDEX.
#
# usage: compare-index.sh [-b] [-i INDEX] [-o OUTDIR]
#
#   -b         build the INDEX in the jail first.  Slow -- time it before
#              putting this on a schedule.
#   -i INDEX   compare against this INDEX instead of the jail's own
#   -o OUTDIR  where to write the lists (default: $SPOOLINGDIR)
#
# Writes three files to OUTDIR, one port per line:
#
#   refresh.txt             version differs, refresh these
#   not-in-index.txt        in FreshPorts, absent from the INDEX
#   not-in-freshports.txt   in the INDEX, absent from FreshPorts
#
# Runs as the freshports user, so the two jexec calls go through sudo.  See
# SUDOERS below for the entries they need.
#
# Only the version is compared, including PORTREVISION and PORTEPOCH.  The
# package name is not: a port's PKGNAMEPREFIX follows DEFAULT_VERSIONS, so
# py311-foo and py312-foo are the same port at the same version.  An
# OSVERSION spliced into a version is ignored too, since it says more about
# the machine than the port.
#
# SUDOERS
#
# These are matched literally, so they must agree with JAILMAKE below, and
# with FRESHPORTS_JAIL_NAME and PORTSDIR in config.sh.  Neither command takes
# an argument from outside the script, so neither needs a wildcard.
#
# freshports     ALL=(ALL) NOPASSWD:/usr/sbin/jexec freshports /usr/bin/make -C /usr/ports -V INDEXFILE
# freshports     ALL=(ALL) NOPASSWD:/usr/sbin/jexec freshports /usr/bin/make -C /usr/ports index
#
# The second is only needed if you run with -b.  Leave it out to keep the
# ability to build an INDEX off this host.

if [ ! -f config.sh ]
then
	echo "config.sh not found by $0"
	exit 1
fi

. config.sh

$LOGGER -t $0[$$] starts

if [ $OFFLINE = 1 ]
then
	$LOGGER -t $0[$$] exits because system is offline
	exit 0
fi

BUILD=0
INDEX=''
OUTDIR="${SPOOLINGDIR}"

while getopts 'bi:o:' option
do
	case $option in
	b)	BUILD=1        ;;
	i)	INDEX=$OPTARG  ;;
	o)	OUTDIR=$OPTARG ;;
	*)	echo "usage: $0 [-b] [-i INDEX] [-o OUTDIR]"; exit 1 ;;
	esac
done

JAILPORTS="${FRESHPORTS_JAIL_BASE_DIR}${PORTSDIR}"

# The database stores element pathnames as /ports/head/category/port, which is
# DB_Root_Prefix_PORTS in the perl config, not PORTSDIR.  The ports table holds
# a row per port per branch, so without this we would compare head against the
# quarterly branches as well.
ELEMENT_HEAD_PREFIX="/ports/head"

# make(1) inside the jail.  Spelled out in full because sudoers matches the
# command line literally, and this has to be the same string there.
JAILMAKE="/usr/bin/make"

if [ "${SUDO}x" = 'x' ]
then
	$LOGGER -t $0[$$] FATAL: SUDO is not set in config.sh
	echo "$0: SUDO is not set in config.sh" >&2
	exit 1
fi

#
# save these values for use by psql via environment variables. The password is stored in ~/.pgpass
#
export PGDATABASE=$DB
export PGHOST=$HOST
export PGUSER=$DBUSER

# see also PGSSLMODE and PGSSLROOTCERT in config.sh

tsv=$(mktemp ${SPOOLINGDIR}/compare-index-tsv.XXXXXX)   || exit 1
out=$(mktemp ${SPOOLINGDIR}/compare-index-out.XXXXXX)   || exit 1

trap "rm -f $tsv $out" EXIT INT TERM

if [ $BUILD = 1 ]
then
	$LOGGER -t $0[$$] building the INDEX in jail $FRESHPORTS_JAIL_NAME
	if ! $SUDO /usr/sbin/jexec $FRESHPORTS_JAIL_NAME $JAILMAKE -C $PORTSDIR index
	then
		$LOGGER -t $0[$$] FATAL: could not build the INDEX
		exit 1
	fi
fi

if [ "${INDEX}x" = 'x' ]
then
	# INDEXFILE is INDEX-15 on 15.x, INDEX-14 on 14.x, and so on.  Ask the
	# jail rather than guessing, so this keeps working across a major bump.
	indexfile=$($SUDO /usr/sbin/jexec $FRESHPORTS_JAIL_NAME $JAILMAKE -C $PORTSDIR -V INDEXFILE)
	if [ "${indexfile}x" = 'x' ]
	then
		$LOGGER -t $0[$$] FATAL: could not determine INDEXFILE
		exit 1
	fi
	INDEX="${JAILPORTS}/${indexfile}"
fi

if [ ! -f $INDEX ]
then
	$LOGGER -t $0[$$] FATAL: no INDEX at $INDEX
	echo "$0: no INDEX at $INDEX" >&2
	exit 1
fi

$LOGGER -t $0[$$] comparing against $INDEX

if ! ${SCRIPTDIR}/index_pkgversions.py -i $INDEX -o $tsv
then
	$LOGGER -t $0[$$] FATAL: could not parse $INDEX
	exit 1
fi

#
# The whole comparison runs in one psql session, so index_ports can be a TEMP
# table and nothing is left behind in the database.  The SELECT goes into a
# TEMP VIEW first because a psql \copy has to fit on one line.
#
if ! $PSQL --quiet --no-psqlrc <<EOF
CREATE TEMP TABLE index_ports (
    origin       text NOT NULL,
    pkgname      text NOT NULL,
    package_name text NOT NULL
);

\copy index_ports FROM '$tsv'

CREATE INDEX ON index_ports (origin);
ANALYZE index_ports;

--
-- strip_osversion(): an OSVERSION says more about the machine which built the
-- INDEX than about the port, so take it out of the version before comparing.
-- It appears in two shapes:
--
--   spliced in    13.1.0.1501502,2  ->  13.1.0,2
--   on its own    1501503           ->  (nothing left)
--
CREATE TEMP VIEW comparison AS
WITH fp AS (
    SELECT pa.category || '/' || pa.name AS origin,
           regexp_replace(regexp_replace(
             pa.version
             || CASE WHEN COALESCE(pa.revision,  '') NOT IN ('', '0')
                     THEN '_' || pa.revision  ELSE '' END
             || CASE WHEN COALESCE(pa.portepoch, '') NOT IN ('', '0')
                     THEN ',' || pa.portepoch ELSE '' END,
             '\.1[45][0-9]{5}(\$|[_,])', '\1'),
             '^1[45][0-9]{5}(\$|[_,])', '\1') AS pkgversion
      FROM ports_active pa
     WHERE element_pathname(pa.element_id) LIKE '${ELEMENT_HEAD_PREFIX}/%'
),
idx AS (
    SELECT origin,
           regexp_replace(regexp_replace(
             regexp_replace(pkgname, '^.*-', ''),
             '\.1[45][0-9]{5}(\$|[_,])', '\1'),
             '^1[45][0-9]{5}(\$|[_,])', '\1') AS pkgversion
      FROM index_ports
),
idx_origins AS (
    SELECT DISTINCT origin FROM index_ports
)
SELECT COALESCE(fp.origin, o.origin) AS origin,
       CASE WHEN fp.origin IS NULL THEN 'not-in-freshports'
            WHEN o.origin  IS NULL THEN 'not-in-index'
            ELSE 'refresh'
       END AS bucket
  FROM fp
  FULL OUTER JOIN idx_origins o ON o.origin = fp.origin
 WHERE fp.origin IS NULL
    OR o.origin  IS NULL
    OR NOT EXISTS (SELECT 1 FROM idx i
                    WHERE i.origin     = fp.origin
                      AND i.pkgversion = fp.pkgversion)
 ORDER BY bucket, origin;

\copy (SELECT * FROM comparison) TO '$out'
EOF
then
	$LOGGER -t $0[$$] FATAL: the comparison failed
	exit 1
fi

# start from empty, so a bucket which found nothing this time says so
for bucket in refresh not-in-index not-in-freshports
do
	: > ${OUTDIR}/${bucket}.txt
done

awk -F'\t' -v outdir="$OUTDIR" '{ print $1 >> (outdir "/" $2 ".txt") }' $out

for bucket in refresh not-in-index not-in-freshports
do
	count=$(wc -l < ${OUTDIR}/${bucket}.txt | tr -d ' ')
	$LOGGER -t $0[$$] $bucket: $count ports
	echo "${count}	${OUTDIR}/${bucket}.txt"
done

$LOGGER -t $0[$$] ends

exit 0
