#!/bin/sh

JAILBASE=$1
PORTSBASE=$2

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
cp -rp etc                    ${JAILBASE}

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
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${PORTSBASE} /cat-descr.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${PORTSBASE} /make-category-comment.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${PORTSBASE} /make-generate-plist.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${PORTSBASE} /make-master-port-test.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${PORTSBASE} /make-master-sites-all.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${PORTSBASE} /make-port.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${PORTSBASE} /make-showconfig.sh *
dan      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u dan ${PORTSBASE} /realpath.sh *
"

echo "This entry is required in scripts/config.sh:

FRESHPORTS_JAIL_BASE_DIR=\"${JAILBASE}\"
"

echo "This entry is required in /usr/local/etc/freshports/config.pm

\$FreshPorts::Config::JailBaseDir = '${JAILBASE}';
"
