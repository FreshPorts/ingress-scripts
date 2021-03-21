#!/bin/sh
#
# This extracts information from a port Makefile
#
# expected usage: sudo /usr/sbin/chroot -u USER JAIL /make-port.sh REPO_PATH PORTDIR
#
# where USER      - user as which to execute the commands.  e.g. dan
#       JAIL      - path to the jail created with the create-jail-directories.sh command. e.g. /usr/jail/FreshPorts
#       REPO_PATH - path to the SVN repository e.g. /usr/local/PORTS-RELENG_9_1_0
#       PORTDIR   - sysutils/bacula-server
#

. ./vars.sh

REPO_PATH=$1
PORT=$2

cd ${REPO_PATH}/${PORT}

${MAKE} -V PORTNAME       -V PKGNAME             -V DESCR                -V CATEGORIES      \
        -V PORTVERSION    -V PORTREVISION        -V COMMENT              -V COMMENTFILE     \
        -V MAINTAINER     -V EXTRACT_SUFX        -V BUILD_DEPENDS        -V RUN_DEPENDS     \
        -V LIB_DEPENDS    -V FORBIDDEN           -V BROKEN               -V DEPRECATED      \
        -V IGNORE         -V MASTER_PORT         -V LATEST_LINK          -V NO_LATEST_LINK  \
        -V NO_PACKAGE     -V PKGNAMEPREFIX       -V PKGNAMESUFFIX        -V PORTEPOCH       \
        -V RESTRICTED     -V NO_CDROM            -V EXPIRATION_DATE      -V IS_INTERACTIVE  \
        -V ONLY_FOR_ARCHS -V NOT_FOR_ARCHS       -V LICENSE              -V FETCH_DEPENDS   \
        -V PATCH_DEPENDS  -V EXTRACT_DEPENDS     -V USES                 -V PKGMESSAGE      \
        -V DISTINFO_FILE  -V _LICENSE_RESTRICTED -V MANUAL_PACKAGE_BUILD -V LICENSE_PERMS   \
        -V CONFLICTS      -V CONFLICTS_BUILD     -V CONFLICTS_INSTALL    -V OPTIONS_NAME    \
        -f ${REPO_PATH}/${PORT}/Makefile \
        PORTSDIR=${REPO_PATH}
