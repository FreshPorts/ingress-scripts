#!/bin/sh

See https://news.freshports.org/2025/06/18/clearing-out-the-distfiles/

PORTSDIR=/usr/ports

cut -d \| -f 2 ${PORTSDIR}/INDEX* | while read d; do cd $d && make -V ALLFILES | tr " " "\n" | grep -v '^$' || : ; done
