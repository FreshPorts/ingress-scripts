#!/bin/sh

# moved away from a chroot to a proper jail

JAILBASE=$1

/bin/cp  -p scripts/*.sh           ${JAILBASE}
/bin/cp  -p scripts/vars.sh.sample ${JAILBASE}
/bin/cp -rp files/etc              ${JAILBASE}

echo This entry is required in scripts/config.sh:
echo FRESHPORTS_JAIL_BASE_DIR=\"${JAILBASE}\"

echo This entry is required in /usr/local/etc/freshports/config.pm
echo \$FreshPorts::Config::JailBaseDir = '${JAILBASE}';
