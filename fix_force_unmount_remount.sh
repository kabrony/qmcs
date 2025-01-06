#!/usr/bin/env bash
set -e

################################################################################
# fix_force_unmount_remount.sh
#
# 1) Force-unmount anything that references /dev/sdb or /dev/disk/by-id/scsi-0DO_Volume_*
#    to ensure we remove old partial mounts (like /mnt/myvolume).
# 2) Mount volumes at /mnt/my_volume and /mnt/volume_sfo3_01.
# 3) Update /etc/fstab so they stay mounted after reboot.
#
# Usage:
#   chmod +x fix_force_unmount_remount.sh
#   ./fix_force_unmount_remount.sh
################################################################################

VOL1_DISK="/dev/disk/by-id/scsi-0DO_Volume_my-volume"
VOL2_DISK="/dev/disk/by-id/scsi-0DO_Volume_volume-sfo3-01"

VOL1_MOUNT="/mnt/my_volume"
VOL2_MOUNT="/mnt/volume_sfo3_01"

###############################################################################
# 1) Find ANY existing mount referencing /dev/sdb or scsi-0DO_Volume_my-volume
#    or scsi-0DO_Volume_volume-sfo3-01 and forcibly unmount them.
###############################################################################
echo "[INFO] Step 1: Force unmounting anything referencing $VOL1_DISK or $VOL2_DISK, or /dev/sdb..."

# We'll parse /proc/mounts to find current mount points referencing them
# Then umount -f for each mount point.

MOUNTS_TO_UNMOUNT=$(grep -E "($VOL1_DISK|$VOL2_DISK|/dev/sdb)" /proc/mounts | awk '{print $2}' || true)

if [ -n "$MOUNTS_TO_UNMOUNT" ]; then
  echo "[WARN] Found these mount points referencing our volumes:"
  echo "$MOUNTS_TO_UNMOUNT"
  for mp in $MOUNTS_TO_UNMOUNT; do
    echo "[INFO] Force-unmounting: $mp"
    sudo umount -f "$mp" || true
  done
else
  echo "[INFO] No existing references found to $VOL1_DISK or $VOL2_DISK or /dev/sdb."
fi

###############################################################################
# 2) Create mount directories if needed
###############################################################################
echo "[INFO] Step 2: Creating mount dirs if not exist..."
sudo mkdir -p "$VOL1_MOUNT"
sudo mkdir -p "$VOL2_MOUNT"

###############################################################################
# 3) Mount the volumes
###############################################################################
echo "[INFO] Step 3: Mounting volumes..."

echo "[INFO] Mounting $VOL1_DISK -> $VOL1_MOUNT"
sudo mount -o discard,defaults,noatime "$VOL1_DISK" "$VOL1_MOUNT"

echo "[INFO] Mounting $VOL2_DISK -> $VOL2_MOUNT"
sudo mount -o discard,defaults,noatime "$VOL2_DISK" "$VOL2_MOUNT"

###############################################################################
# 4) Update /etc/fstab for persistence
###############################################################################
echo "[INFO] Step 4: Updating /etc/fstab..."

sudo sed -i "\|$VOL1_DISK|d" /etc/fstab
sudo sed -i "\|$VOL2_DISK|d" /etc/fstab

# Append fresh lines
echo "$VOL1_DISK $VOL1_MOUNT ext4 defaults,nofail,discard 0 0" | sudo tee -a /etc/fstab
echo "$VOL2_DISK $VOL2_MOUNT ext4 defaults,nofail,discard 0 0" | sudo tee -a /etc/fstab

###############################################################################
# 5) Show final mount status
###############################################################################
echo "[INFO] Step 5: Final status (df -h & mount | grep /mnt/)..."
df -h | grep '/mnt/'
mount | grep -E "$VOL1_MOUNT|$VOL2_MOUNT"
echo "[DONE] Volumes forced unmounted, remounted, and updated in /etc/fstab."
