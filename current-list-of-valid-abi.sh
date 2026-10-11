#!/bin/sh

# ABI marked "(only pkgbase is updated)" have no ports packages (no latest/quarterly),
# so exclude them - e.g. FreeBSD:15:riscv64

fetch -qo - https://pkg.freebsd.org/index.html | \
  grep FreeBSD: | grep -v 'only pkgbase is updated' | sed -e 's@.*\(FreeBSD:[^ <]*\).*@\1@' | sort
