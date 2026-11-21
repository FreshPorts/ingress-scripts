#!/bin/sh

# The goal of this is to obtain a list of valid categories from the FreeBSD ports tree.
# There are two types of categories:
# * primary/real/physical - exist on disk
# * virtual - not see on disk
#
# A port may be belong to more than one category and must be in at least one primary category.
# The primary category must be listed first.
#
# Based upon discussion in EFNET #bsdports channel on 2021-04-20
# contributors include: mat _0mp
#
# example output:
#
# [dan@devgit-ingress01:/usr/ports] $ find -s -f * -type d -regex '[a-z].*' -maxdepth 0 | xargs
# accessibility arabic archivers astro audio base benchmarks biology cad chinese comms converters databases 
# deskutils devel dns editors emulators finance french ftp games german graphics hebrew hungarian irc japanese
# java korean lang mail math misc multimedia net net-im net-mgmt net-p2p news polish ports-mgmt portuguese print
# russian science security shells sysutils textproc ukrainian vietnamese www x11 x11-clocks x11-drivers x11-fm 
# x11-fonts x11-servers x11-themes x11-toolkits x11-wm
#
# $ find -s -f * -type d -regex '[a-z].*' -maxdepth 0 | xargs | wc -w
#       62
#
# compare against:
# freshports.devgit=# select count(*) from categories where is_primary;
#  count 
# -------
#     67
# (1 row)
# 
#
# The plan: with each commit, get a list of the current categories. At one time, the number of special directories
# in the top level of the repo was manageable. With the recent addition of the .hooks directory, this issue came to
# light. FreshPorts assumes .hooks is a category. This will avoid that.
# We will load this up at run time, and have it.
#
# There is also this method:
#
# $ make -DCATEGORIES -f Mk/bsd.port.mk -V VALID_CATEGORIES
# accessibility afterstep arabic archivers astro audio  benchmarks biology cad chinese comms converters  databases
# deskutils devel dns docs  editors education elisp emulators enlightenment finance french ftp  games geography german
# gnome gnustep graphics  hamradio haskell hebrew hungarian irc japanese java  kde  kld korean  lang linux lisp 
#  mail mate math mbone misc multimedia  net net-im net-mgmt net-p2p net-vpn news  parallel pear perl5 plan9 polish 
# ports-mgmt portuguese  print python ruby rubygems russian  scheme science security shells spanish sysutils  tcl
# textproc tk  ukrainian vietnamese wayland windowmaker www  x11 x11-clocks x11-drivers x11-fm x11-fonts x11-servers
#  x11-themes  x11-toolkits x11-wm xfce zope base
#
# I have no idea why some of those have extra spaces. That list includes virtual categories as well.
#

CONFIG='/usr/local/etc/freshports/config.sh'

if [ ! -f ${CONFIG} ]
then
	echo "${CONFIG} not found by $0..."
	exit 1
fi

. ${CONFIG}

# we purposely do not check OFFLINE
# if we have taken everything offline for testing, we still want to get a list of current categories
# This touches disk only, not the database.

#if [ $OFFLINE = 1 ]
#then
#	exit 0
#fi

PORTSTREE="${FRESHPORTS_JAIL_BASE_DIR}/${PORTSDIR}"

if ! cd "${PORTSTREE}"
then
	echo "$0: cannot cd to the ports tree ${PORTSTREE}" >&2
	exit 1
fi

#
# The top-level directories which start with a lower-case letter, sorted:
# accessibility arabic archivers ...
#
# This used to be "find -s -f * ...".  When the ports tree was empty, *
# matched nothing and stayed a literal *, so find read -type as options
# and failed with "illegal option -- t".  The pipeline still exited 0,
# with xargs's status, so the caller got an empty list and carried on
# as if the ports tree had no categories.  Search . instead, and fail
# when nothing is found.
#
CATEGORIES=$(/usr/bin/find -s . -mindepth 1 -maxdepth 1 -type d -name '[a-z]*' | /usr/bin/sed 's|^\./||' | /usr/bin/xargs)

if [ -z "${CATEGORIES}" ]
then
	echo "$0: no categories found in ${PORTSTREE}" >&2
	exit 1
fi

echo "${CATEGORIES}"
