#!/bin/bash
# Usage: umockdev-run -d xxx.umockdev -- ./run_test.sh udevadm info /sys/class/...

set -eux
set -o pipefail

UMOCKDEV_DIR="${UMOCKDEV_DIR:?This script should run under umockdev-run}"
DROPIN="/etc/systemd/system/systemd-udevd.service.d/99-umockdev.conf"

at_exit() {
    rm -f "$DROPIN"
    # Recreate the udev database _without_ the umockdev's preload DSO
    unset LD_PRELOAD UMOCKDEV_DIR
    systemctl daemon-reload
    systemctl restart systemd-udevd
    udevadm control --ping
    udevadm info -c
    udevadm trigger --settle
}

trap at_exit EXIT

# Wrap the systemd-udevd service with umockdev's preload DSO, so it redirects
# all sysfs and netlink operations to the testbed
mkdir -p "$(dirname "$DROPIN")"
cat >"$DROPIN" <<EOF
[Service]
ExecStart=
ExecStart=/bin/umockdev-wrapper /usr/lib/systemd/systemd-udevd
Environment=UMOCKDEV_DIR=$UMOCKDEV_DIR
Environment=UMOCKDEV_DEBUG=all
EOF

systemctl daemon-reload
systemctl restart systemd-udevd
# Wait until udev is ready
udevadm control --ping
# Clean its database
udevadm info -c
# Repopulate the udev database, so it includes devices from the umockdev's
# testbed
udevadm trigger

"$@"
