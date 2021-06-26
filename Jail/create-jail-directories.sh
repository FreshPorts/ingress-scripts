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
cp -rp files/etc              ${JAILBASE}

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
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${PORTSBASE} /cat-descr.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${PORTSBASE} /make-apply-slist.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${PORTSBASE} /make-category-comment.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${PORTSBASE} /make-flavors-package-names.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${PORTSBASE} /make-generate-plist.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${PORTSBASE} /make-master-port-test.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${PORTSBASE} /make-master-sites-all.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${PORTSBASE} /make-port.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${PORTSBASE} /make-showconfig.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${PORTSBASE} /realpath.sh *
"

echo This entry is required in scripts/config.sh:

echo FRESHPORTS_JAIL_BASE_DIR=\"${JAILBASE}\"


echo This entry is required in /usr/local/etc/freshports/config.pm

echo \$FreshPorts::Config::JailBaseDir = '${JAILBASE}';
