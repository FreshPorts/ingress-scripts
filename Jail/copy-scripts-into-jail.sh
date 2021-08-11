#!/bin/sh

# moved away from a chroot to a proper jail

JAILBASE=$1

/bin/cp  -p scripts/*.sh           ${JAILBASE}
/bin/cp  -p scripts/vars.sh.sample ${JAILBASE}
/bin/cp -rp files/etc              ${JAILBASE}

# any sudoers commands are usually controlled by ansible

echo "Put the following in sudoers
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/jexec $(basename ${JAILBASE}) /cat-descr.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/jexec $(basename ${JAILBASE}) /make-category-comment.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/jexec $(basename ${JAILBASE}) /make-flavors-package-names.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/jexec $(basename ${JAILBASE}) /make-generate-plist.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/jexec $(basename ${JAILBASE}) /make-master-port-test.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/jexec $(basename ${JAILBASE}) /make-master-sites-all.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/jexec $(basename ${JAILBASE}) /make-pkg-message.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/jexec $(basename ${JAILBASE}) /make-port.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/jexec $(basename ${JAILBASE}) /make-showconfig.sh *
freshports      ALL=(ALL) NOPASSWD:/usr/sbin/jexec $(basename ${JAILBASE}) /realpath.sh *
"

echo This entry is required in scripts/config.sh:

echo FRESHPORTS_JAIL_BASE_DIR=\"${JAILBASE}\"


echo This entry is required in /usr/local/etc/freshports/config.pm

echo \$FreshPorts::Config::JailBaseDir = '${JAILBASE}';
