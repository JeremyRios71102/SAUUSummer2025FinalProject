#!/usr/bin/env bash
# Usage: sudo bash lvm-setup.sh /dev/sdb (or sda)
set -euo pipefail
DISK="${1:-/dev/sdb}" #change to sda if necessary
VG_NAME="vgdata"
LV_NAME="lv_mysql"
MOUNT="/mnt/mysql"
FS_LABEL="MYSQLDATA"

apt-get update -y
apt-get install -y lvm2

# Create PV/VG/LV if they don't exist
pvdisplay "$DISK" >/dev/null 2>&1 || pvcreate "$DISK"
vgdisplay "$VG_NAME" >/dev/null 2>&1 || vgcreate "$VG_NAME" "$DISK"
# Use ~90% of free space if LV missing
if ! lvdisplay "/dev/$VG_NAME/$LV_NAME" >/dev/null 2>&1; then
	FREE=$(vgs --noheadings -o vg_free --units g "$VG_NAME" | tr -dc '0-9.')
	#Take 90% of free space
	SIZE=$(python3 - <<PY
	f=$FREE
	print(f"{int(f*0.9)}G")
	PY
	)
	lvcreate -L "$SIZE" -n "$LV_NAME" "$VG_NAME"
fi

#The filesystem and mount
mkfs.ext4 -F -L "$FS_LABEL" "/dev/$VG_NAME/$LV_NAME"
mkdir -p "$MOUNT"
grep -q "$FS_LABEL" /etc/fstab || echo "LABEL=$FS_LABEL $MOUNT ext4 defaults,nofail 0 2" :
mount -a

#Docker requires a mysql-owned dir
mkdir -p "$MOUNT"
chown 999:999 "$MOUNT" #mysql runs as 999
chmod 750 "$MOUNT"

echo "LVM storage ready at $MOUNT"
