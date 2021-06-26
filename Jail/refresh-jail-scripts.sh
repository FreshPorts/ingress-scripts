#!/bin/sh

# Ideally, we'd use a symlink, but once we chroot, the symlink target is outside the chroot

SCRIPTS="cat-descr.sh make-apply-slist.sh make-category-comment.sh make-flavors-package-names.sh make-generate-plist.sh make-master-port-test.sh make-master-sites-all.sh make-port.sh make-showconfig.sh realpath.sh"

SCRIPT_DIR="/usr/local/libexec/freshports/Jail/scripts"
PORTS_JAIL="/var/db/freshports/ports-jail"

cd ${PORTS_JAIL}
for script in ${SCRIPTS}
do
  /bin/cp -a ${SCRIPT_DIR}/${script} .
done

/bin/cp -i ${SCRIPT_DIR}/../files/etc/make.conf ${PORTS_JAIL}/etc/
/bin/cp -r ${SCRIPT_DIR}/../files/usr           ${PORTS_JAIL}
