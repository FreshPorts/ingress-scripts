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
# usage: compare-index.sh [-b] [-c COMMIT] [-i INDEX] [-o OUTDIR] [-F]
#
#   -b         build the INDEX first, in the index jail.  Without this the
#              INDEX already sitting in that jail is used, however old.
#   -F         compare even if the INDEX has not changed since the last run.
#              For testing: the comparison is the part worth repeating.
#   -c COMMIT  check the index jail's ports tree out at this commit before
#              building.  Only meaningful with -b.
#   -i INDEX   compare against this INDEX instead of the index jail's own
#   -o OUTDIR  where to write the lists (default: $SPOOLINGDIR)
#
# The INDEX is checksummed, and the checksum kept in SPOOLINGDIR.  An INDEX
# which has not changed since the last run is not processed again.  Note this
# gates on one of the two inputs: the database moves independently, so after
# commit processing catches up the answer can differ while the INDEX has not.
# Pass -F to compare anyway, or remove the checksum:
#
#   rm ${SPOOLINGDIR}/compare-index.md5
#
# Writes three files to OUTDIR, one port per line:
#
#   refresh.txt             version differs, refresh these
#   not-in-index.txt        in FreshPorts, absent from the INDEX
#   not-in-freshports.txt   in the INDEX, absent from FreshPorts
#
# Runs as the freshports user.  Building needs sudo twice: to check the index
# jail's ports tree out, and to run make in that jail.  See SUDOERS below.
# Neither is needed without -b.
#
# Only the version is compared, including PORTREVISION and PORTEPOCH.  The
# package name is not: a port's PKGNAMEPREFIX follows DEFAULT_VERSIONS, so
# py311-foo and py312-foo are the same port at the same version.  An
# OSVERSION spliced into a version is ignored too, since it says more about
# the machine than the port.
#
# The INDEX is built in the index jail rather than in the freshports one:
# make index needs perl, and the freshports jail has no packages installed.
# The index jail carries its own ports tree, synchronised with the freshports
# one.
#
# Pass -c with the commit FreshPorts has finished processing.  The tree is
# checked out there first, so the INDEX describes the same tree state the
# database was built from.  Without it the INDEX describes whatever state
# that tree happens to be in, and anything which moved in between is reported
# as a difference when it is really just the two sides being read at
# different moments.
#
# SUDOERS
#
# These are matched literally, so they must agree with GIT, MAKE and the
# paths below, which are built from INDEX_JAIL_NAME, INDEX_JAIL_BASE_DIR and
# PORTSDIR in config.sh.
#
# freshports     ALL=(ALL) NOPASSWD:/usr/local/bin/git -C /jails/index/usr/ports checkout *
# freshports     ALL=(ALL) NOPASSWD:/usr/sbin/jexec index /usr/bin/make -C /usr/ports index
#
# Only -b needs them, and only -c needs the first.  Reading INDEXDIR and
# INDEXFILE writes nothing and runs as the invoking user, so a run against an
# INDEX built elsewhere -- or pointed at with -i -- needs no sudo at all.
#
# The checkout entry ends in a wildcard because the commit is supplied by the
# caller.  The script checks it is a hex hash of at least seven characters
# before passing it on, so an option cannot be smuggled through in its place.

if [ ! -f config.sh ]
then
	echo "config.sh not found by $0"
	exit 1
fi

. config.sh

# Every failure has to reach both syslog, for the scheduled runs, and stderr,
# for the person who just typed the command.  Logging only to syslog is how a
# failure looks like success at the terminal.
fatal() {
	$LOGGER -t $0[$$] "FATAL: $*"
	echo "$0: $*" >&2
	exit 1
}

info() {
	$LOGGER -t $0[$$] "$*"
	echo "$0: $*"
}

$LOGGER -t $0[$$] starts

if [ $OFFLINE = 1 ]
then
	$LOGGER -t $0[$$] exits because system is offline
	exit 0
fi

BUILD=0
FORCE=0
COMMIT=''
INDEX=''
OUTDIR="${SPOOLINGDIR}"

while getopts 'bFc:i:o:' option
do
	case $option in
	b)	BUILD=1        ;;
	F)	FORCE=1        ;;
	c)	COMMIT=$OPTARG ;;
	i)	INDEX=$OPTARG  ;;
	o)	OUTDIR=$OPTARG ;;
	*)	echo "usage: $0 [-b] [-c COMMIT] [-i INDEX] [-o OUTDIR] [-F]"; exit 1 ;;
	esac
done

# the ports tree of the index jail, as seen from the host
JAILPORTS="${INDEX_JAIL_BASE_DIR}${PORTSDIR}"

# The ports table holds a row per port per branch, so head has to be picked
# out or we would compare it against the quarterly branches as well.  The
# pathnames look like /ports/head/category/port -- that prefix is
# DB_Root_Prefix_PORTS in the perl config, not PORTSDIR.
#
# ports_active already restricts itself to head.  Saying so again costs one
# comparison on a column the view hands us, makes the intent visible, and
# means this still selects head if that view is ever widened.
ELEMENT_HEAD_PREFIX="/ports/head"

# Spelled out in full because sudoers matches the command line literally, and
# these have to be the same strings there.
MAKE="/usr/bin/make"

# Reading INDEXDIR and INDEXFILE happens on the host, against the index
# jail's tree.  Both parts are needed: -C is where make runs; PORTSDIR is
# where it looks for the Mk files AND, through INDEXDIR, where the INDEX
# lands.  PORTSDIR defaults to /usr/ports whatever -C says, so without this
# the host's own ports tree is read instead of the jail's.
MAKEPORTS="-C ${JAILPORTS} PORTSDIR=${JAILPORTS}"

MD5="/sbin/md5"

# Where the last INDEX checksum is kept.  SPOOLINGDIR, not OUTDIR: this has to
# survive a run which wrote its lists somewhere else.
MD5FILE="${SPOOLINGDIR}/compare-index.md5"

#
# config.sh is deployed separately from this script, so a new variable can be
# missing from it.  Unset expands to nothing, which silently builds a command
# with a hole in it -- jexec with no jail name, a path starting at the wrong
# root -- so check, and name the one which is missing.
#
required='INDEX_JAIL_BASE_DIR'

if [ $BUILD = 1 ]
then
	required="$required SUDO GIT INDEX_JAIL_NAME"
fi

for variable in $required
do
	eval value=\$$variable

	if [ "${value}x" = 'x' ]
	then
		fatal "$variable is not set in config.sh"
	fi
done

#
# save these values for use by psql via environment variables. The password is stored in ~/.pgpass
#
export PGDATABASE=$DB
export PGHOST=$HOST
export PGUSER=$DBUSER

# see also PGSSLMODE and PGSSLROOTCERT in config.sh

tsv=$(mktemp    ${SPOOLINGDIR}/compare-index-tsv.XXXXXX)    || exit 1
out=$(mktemp    ${SPOOLINGDIR}/compare-index-out.XXXXXX)    || exit 1
loaded=$(mktemp ${SPOOLINGDIR}/compare-index-loaded.XXXXXX) || exit 1

trap "rm -f $tsv $out $loaded" EXIT INT TERM

if [ "${COMMIT}x" != 'x' -a $BUILD = 0 ]
then
	fatal "-c is only meaningful with -b"
fi

if [ $BUILD = 1 ]
then
	if [ "${COMMIT}x" != 'x' ]
	then
		#
		# The commit reaches sudo, and the sudoers entry has to end in a
		# wildcard because it varies.  Check it is a hash and nothing else,
		# so no option can be smuggled through in its place.
		#
		case "$COMMIT" in
		*[!0-9a-f]*)
			fatal "commit '$COMMIT' is not a hex hash"
			;;
		esac

		if [ ${#COMMIT} -lt 7 ]
		then
			fatal "commit '$COMMIT' is too short to be a hash"
		fi

		info "checking $JAILPORTS out at $COMMIT"
		if ! $SUDO $GIT -C $JAILPORTS checkout $COMMIT
		then
			fatal "could not check $JAILPORTS out at $COMMIT"
		fi
	else
		info "building the INDEX from $JAILPORTS as it stands, no commit given"
	fi

	#
	# make index runs inside the jail, where perl is.  PORTSDIR needs no
	# override there: /usr/ports is the tree.
	#
	info "building the INDEX in jail $INDEX_JAIL_NAME"
	if ! $SUDO /usr/sbin/jexec $INDEX_JAIL_NAME $MAKE -C $PORTSDIR index
	then
		fatal "could not build the INDEX in jail $INDEX_JAIL_NAME"
	fi
fi

if [ "${INDEX}x" = 'x' ]
then
	# Ask make where fetchindex puts the file rather than working it out.
	# INDEXDIR is where it lands, INDEXFILE is what it is called -- INDEX-15
	# on 15.x, INDEX-14 on 14.x -- so this keeps working across a major bump,
	# and says so out loud if either ever moves.
	#
	# No sudo: reading a variable writes nothing.
	indexdir=$($MAKE $MAKEPORTS -V INDEXDIR)
	indexfile=$($MAKE $MAKEPORTS -V INDEXFILE)

	if [ "${indexdir}x" = 'x' -o "${indexfile}x" = 'x' ]
	then
		fatal "could not determine INDEXDIR or INDEXFILE from $JAILPORTS"
	fi

	INDEX="${indexdir}/${indexfile}"
fi

if [ ! -f $INDEX ]
then
	fatal "no INDEX at $INDEX"
fi

if [ ! -s $INDEX ]
then
	fatal "the INDEX at $INDEX is empty"
fi

md5=$($MD5 -q $INDEX)

if [ "${md5}x" = 'x' ]
then
	fatal "could not checksum $INDEX"
fi

if [ -f $MD5FILE ]
then
	previous=$(cat $MD5FILE)
else
	previous=''
fi

info "INDEX $INDEX md5 $md5, previously ${previous:-none}"

if [ "$md5" = "$previous" ]
then
	if [ $FORCE = 0 ]
	then
		info "INDEX unchanged, not processing"
		exit 0
	fi

	info "INDEX unchanged, processing anyway: -F"
else
	info "INDEX changed, processing"
fi

if ! ${SCRIPTDIR}/index_pkgversions.py -i $INDEX -o $tsv
then
	fatal "could not parse $INDEX"
fi

if [ ! -s $tsv ]
then
	fatal "no packages parsed out of $INDEX"
fi

info "$(wc -l < $tsv | tr -d ' ') packages read from the INDEX"

#
# The whole comparison runs in one psql session, so index_ports can be a TEMP
# table and nothing is left behind in the database.  The SELECT goes into a
# TEMP VIEW first because a psql \copy has to fit on one line.
#
# ON_ERROR_STOP is what makes a failed statement a failed run.  Without it
# psql complains on stderr and still exits 0, so a broken query, a missing
# table or a refused connection all look like a clean run with no differences.
if ! $PSQL --quiet --no-psqlrc -v ON_ERROR_STOP=1 <<EOF
CREATE TEMP TABLE index_ports (
    origin       text NOT NULL,
    pkgname      text NOT NULL,
    package_name text NOT NULL
);

\copy index_ports FROM '$tsv'

\copy (SELECT count(*) FROM index_ports) TO '$loaded'

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
     WHERE pa.pathname LIKE '${ELEMENT_HEAD_PREFIX}/%'
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
	fatal "the comparison failed -- see the psql errors above"
fi

#
# Confirm we compared against what we just parsed.  Loading a stale file, or
# loading nothing at all, otherwise reports a clean run.
#
expected=$(wc -l < $tsv | tr -d ' ')
actual=$(cat $loaded)

if [ "${actual}x" = 'x' ]
then
	fatal "psql returned no row count -- did it connect?"
fi

if [ "$actual" != "$expected" ]
then
	fatal "loaded $actual rows but the INDEX gave $expected"
fi

info "$actual rows loaded and compared"

# start from empty, so a bucket which found nothing this time says so
for bucket in refresh not-in-index not-in-freshports
do
	: > ${OUTDIR}/${bucket}.txt
done

if ! awk -F'\t' -v outdir="$OUTDIR" '{ print $1 >> (outdir "/" $2 ".txt") }' $out
then
	fatal "could not write the lists to $OUTDIR"
fi

for bucket in refresh not-in-index not-in-freshports
do
	count=$(wc -l < ${OUTDIR}/${bucket}.txt | tr -d ' ')
	$LOGGER -t $0[$$] $bucket: $count ports
	echo "${count}	${OUTDIR}/${bucket}.txt"
done

#
# Only now, with the lists written, is this INDEX one we have finished with.
# Recording it earlier would mean a failed run was never retried.
#
echo $md5 > $MD5FILE

$LOGGER -t $0[$$] ends

exit 0
