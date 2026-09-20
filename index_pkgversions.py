#!/usr/local/bin/python3

# Compile a list of packages from a ports INDEX file, one tab separated line
# per INDEX entry:
#
#   accessibility/accerciser<tab>accerciser-3.48.0<tab>accerciser
#
# that is, the origin, PKGNAME with its version, and the package name on its
# own.
#
# Every entry is emitted.  A flavored port appears in the INDEX once per
# flavor, all under the one origin, and which of them is the default is not
# something the INDEX tells us.  Keeping them all lets the comparison ask
# whether the version FreshPorts holds is among them, rather than guessing.
#
# The INDEX is pipe separated.  We want the first two fields:
#
#   field 1  PKGNAME, e.g. mysql80-client-8.0.36
#   field 2  the port directory, e.g. /usr/ports/databases/mysql80-client
#
# PKGNAME is ${PKGNAMEPREFIX}${PORTNAME}${PKGNAMESUFFIX}-${PKGVERSION} and
# PKGVERSION itself never contains a hyphen, so the last hyphen separates the
# package name from the version.  PKGVERSION carries the revision and epoch
# when set: 1.2.3_4,5
#
# usage: index_pkgversions.py [-i INDEX] [-o OUTPUT] [--json] [--quiet]

import argparse
import bz2
import gzip
import json
import os
import sys

DEFAULT_INDEX = '/usr/ports/INDEX-15'


def open_index(pathname):
    # the distributed INDEX is often compressed, so take it either way.
    #
    # errors='replace' because COMMENT is free text and has been known to
    # carry bytes which are not valid UTF-8.  We only read fields 1 and 2,
    # which are ASCII, so nothing we care about is damaged by this.
    if pathname == '-':
        return sys.stdin

    if pathname.endswith('.bz2'):
        return bz2.open(pathname, 'rt', encoding='utf-8', errors='replace')

    if pathname.endswith('.gz'):
        return gzip.open(pathname, 'rt', encoding='utf-8', errors='replace')

    return open(pathname, 'r', encoding='utf-8', errors='replace')


def parse_line(line):
    # returns (origin, pkgname, name), or raises ValueError

    fields = line.split('|')
    if len(fields) < 2:
        raise ValueError('fewer than 2 fields')

    pkgname, directory = fields[0].strip(), fields[1].strip()

    if not pkgname or not directory:
        raise ValueError('empty PKGNAME or port directory')

    name, separator, pkgversion = pkgname.rpartition('-')
    if not separator or not name or not pkgversion:
        raise ValueError("no version in PKGNAME '%s'" % pkgname)

    # /usr/ports/databases/mysql80-client -> databases/mysql80-client
    parts = os.path.normpath(directory).split('/')
    if len(parts) < 2:
        raise ValueError("no category in port directory '%s'" % directory)

    origin = '/'.join(parts[-2:])

    return origin, pkgname, name


def parse_index(f, warn):
    # returns ([(origin, pkgname, name)], malformed)

    rows = []
    malformed = 0

    for number, line in enumerate(f, start=1):
        line = line.strip()
        if not line:
            continue

        try:
            rows.append(parse_line(line))
        except ValueError as problem:
            malformed += 1
            warn('line %d: %s' % (number, problem))

    return rows, malformed


def main():
    parser = argparse.ArgumentParser(
        description='Compile PKGNAME, package name and origin from a ports INDEX.')
    parser.add_argument('-i', '--index', default=DEFAULT_INDEX,
                        help="INDEX to read, '-' for stdin (default: %s)" % DEFAULT_INDEX)
    parser.add_argument('-o', '--output', default='-',
                        help="where to write, '-' for stdout (default: stdout)")
    parser.add_argument('--json', action='store_true',
                        help='write a JSON array instead of tab separated lines')
    parser.add_argument('--quiet', action='store_true',
                        help='do not report malformed lines or the summary')
    args = parser.parse_args()

    def warn(message):
        if not args.quiet:
            print('%s: %s' % (os.path.basename(sys.argv[0]), message),
                  file=sys.stderr)

    try:
        f = open_index(args.index)
    except OSError as problem:
        print('%s: %s' % (os.path.basename(sys.argv[0]), problem), file=sys.stderr)
        return 1

    try:
        rows, malformed = parse_index(f, warn)
    finally:
        if f is not sys.stdin:
            f.close()

    # by origin first, the key the database is compared on, then by package
    # so that a port's flavors come out in a stable order
    rows.sort()

    out = sys.stdout if args.output == '-' else open(args.output, 'w', encoding='utf-8')
    try:
        if args.json:
            json.dump([{'origin': origin, 'pkgname': pkgname, 'package_name': name}
                       for origin, pkgname, name in rows],
                      out, indent=2)
            out.write('\n')
        else:
            for origin, pkgname, name in rows:
                out.write('%s\t%s\t%s\n' % (origin, pkgname, name))
    finally:
        if out is not sys.stdout:
            out.close()

    origins = len(set(origin for origin, _, _ in rows))
    warn('%d rows, %d origins, %d malformed lines' %
         (len(rows), origins, malformed))

    # nothing parsed at all means the file was not an INDEX
    return 0 if rows else 1


if __name__ == '__main__':
    sys.exit(main())
