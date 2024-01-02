#!/bin/sh

fetch -qo - https://pkg.freebsd.org/index.html | \
  grep FreeBSD: | sed -e 's@.*\(FreeBSD:[^ <]*\).*@\1@' | sort
