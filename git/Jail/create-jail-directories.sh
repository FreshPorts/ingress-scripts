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

# any sudoers commands are usually controlled by ansible

echo "Put the following in sudoers
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${JAILBASE} /cat-descr.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${JAILBASE} /make-category-comment.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${JAILBASE} /make-flavors-package-names.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${JAILBASE} /make-generate-plist.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${JAILBASE} /make-master-port-test.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${JAILBASE} /make-master-sites-all.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${JAILBASE} /make-pkg-message.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${JAILBASE} /make-port.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${JAILBASE} /make-showconfig.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/chroot -u freshports ${JAILBASE} /realpath.sh *
"

echo This entry is required in scripts/config.sh:

echo FRESHPORTS_JAIL_BASE_DIR=\"${JAILBASE}\"


echo This entry is required in /usr/local/etc/freshports/config.pm

echo \$FreshPorts::Config::JailBaseDir = '${JAILBASE}';
