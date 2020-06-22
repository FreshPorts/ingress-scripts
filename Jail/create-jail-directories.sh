#!/bin/sh

JAILBASE=$1

mkdir -p ${JAILBASE}/usr/ports    \
         ${JAILBASE}/usr/share/mk \
         ${JAILBASE}/usr/sbin     \
         ${JAILBASE}/usr/bin      \
         ${JAILBASE}/libexec      \
         ${JAILBASE}/usr/lib      \
         ${JAILBASE}/sbin         \
         ${JAILBASE}/lib          \
         ${JAILBASE}/bin          \
         ${JAILBASE}/dev
         
cp  -p scripts/*.sh           ${JAILBASE}
cp  -p scripts/vars.sh.sample ${JAILBASE}
cp -rp file/etc               ${JAILBASE}

echo "
# Put the following in /etc/fstab
/usr/share/mk                   ${JAILBASE}/usr/share/mk     nullfs  ro,nosuid,noexec        0       0
/usr/sbin                       ${JAILBASE}/usr/sbin         nullfs  ro,nosuid               0       0
/usr/bin                        ${JAILBASE}/usr/bin          nullfs  ro,nosuid               0       0
/libexec                        ${JAILBASE}/libexec          nullfs  ro,nosuid               0       0
/usr/lib                        ${JAILBASE}/usr/lib          nullfs  ro,nosuid               0       0
/sbin                           ${JAILBASE}/sbin             nullfs  ro,nosuid               0       0
/lib                            ${JAILBASE}/lib              nullfs  ro,nosuid               0       0
/bin                            ${JAILBASE}/bin              nullfs  ro,nosuid               0       0
none                            ${JAILBASE}/dev              devfs   rw                      0       0
"


echo "Put the following in sudoers
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${JAILBASE} /cat-descr.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${JAILBASE} /make-category-comment.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${JAILBASE} /make-generate-plist.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${JAILBASE} /make-master-port-test.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${JAILBASE} /make-master-sites-all.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${JAILBASE} /make-port.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${JAILBASE} /make-showconfig.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${JAILBASE} /realpath.sh *
"

echo "This entry is required in scripts/config.sh:

FRESHPORTS_JAIL_BASE_DIR=\"${JAILBASE}\"
"

echo "This entry is required in /usr/local/etc/freshports/config.pm

\$FreshPorts::Config::JailBaseDir = '${JAILBASE}';
"
