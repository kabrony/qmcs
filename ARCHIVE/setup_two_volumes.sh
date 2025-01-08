#!/usr/bin/env bash
set -e

###############################################################################
# setup_two_volumes.sh
#
# Example script to manage two DO Block Storage volumes by:
#  1) Force-unmounting existing mounts.
#  2) Checking if volumes need formatting (ext4).
#  3) Writing new UUID-based lines to /etc/fstab.
#  4) Reloading systemd config and mounting volumes via mount -a.
#
# Usage:
#   sudo ./setup_two_volumes.sh
#
# Variables you need to customize:
#   VOL1_DEV, VOL2_DEV: device paths (e.g. /dev/disk/by-id/scsi-0DO_Volume_my-volume).
#   VOL1_MOUNT, VOL2_MOUNT: mount points (e.g. /mnt/my_volume).
###############################################################################

# EDIT THESE to match your environment
VOL1_DEV="/dev/disk/by-id/scsi-0DO_Volume_my-volume"
VOL2_DEV="/dev/disk/by-id/scsi-0DO_Volume_volume-sfo3-01"

VOL1_MOUNT="/mnt/my_volume"
VOL2_MOUNT="/mnt/volume_sfo3_01"

FILESYSTEM_TYPE="ext4"

###############################################################################
# Preliminary checks
###############################################################################
if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Must run as root (sudo)."
  exit 1
fi

echo "[INFO] Config:"
echo "       1) $VOL1_DEV => $VOL1_MOUNT"
echo "       2) $VOL2_DEV => $VOL2_MOUNT"
echo "       Filesystem type: $FILESYSTEM_TYPE"

###############################################################################
# Step 1) Force-unmount existing references
###############################################################################
echo ""
echo "[INFO] Step 1: Checking for existing mounts referencing $VOL1_DEV or $VOL2_DEV..."

# Regex matches lines starting with these devs
DEVICE_GREP="^(${VOL1_DEV}|${VOL2_DEV})[[:space:]]"
EXISTING=$(grep -E "$DEVICE_GREP" /proc/mounts || true)

if [ -n "$EXISTING" ]; then
  echo "[WARN] Found references in /proc/mounts:"
  echo "$EXISTING"
  # Column 2 = mount point
  MOUNTPOINTS=$(echo "$EXISTING" | awk '{print $2}')
  for MP in $MOUNTPOINTS; do
    echo "[INFO] Force-unmounting: $MP"
    if ! umount -f "$MP"; then
      echo "[WARN] Failed to force-unmount $MP; check logs."
    fi
  done
else
  echo "[INFO] No existing references found."
fi

echo "[INFO] Removing any stale /etc/fstab lines referencing $VOL1_DEV or $VOL2_DEV..."
sed -i "\|$VOL1_DEV|d" /etc/fstab || true
sed -i "\|$VOL2_DEV|d" /etc/fstab || true

###############################################################################
# Step 2) Create mount directories
###############################################################################
echo ""
echo "[INFO] Step 2: Creating mount directories (if needed)..."
mkdir -p "$VOL1_MOUNT"
mkdir -p "$VOL2_MOUNT"

###############################################################################
# Step 3) Check or format each volume
###############################################################################
format_if_needed() {
  local DEV="$1"
  local FSTYPE="$FILESYSTEM_TYPE"
  echo "[INFO] Checking filesystem on $DEV..."
  if blkid "$DEV" | grep -q "TYPE="; then
    echo "[INFO] Filesystem found on $DEV. Skipping format."
  else
    echo "[WARN] No filesystem on $DEV. We'll format it as $FSTYPE (data destructive)."
    echo -n "Proceed with formatting $DEV? [y/N]: "
    read -r proceed
    if [[ "$proceed" =~ ^[Yy]$ ]]; then
      echo -n "Type 'YES' to confirm formatting $DEV: "
      read -r confirm
      if [ "$confirm" = "YES" ]; then
        echo "[INFO] Formatting $DEV as $FSTYPE..."
        mkfs."$FSTYPE" -F "$DEV"
      else
        echo "[ERROR] Canceled formatting. Exiting."
        exit 1
      fi
    else
      echo "[ERROR] Not formatting => cannot proceed with mounting. Exiting."
      exit 1
    fi
  fi
}

echo ""
echo "[INFO] Step 3: Checking and possibly formatting volumes..."
format_if_needed "$VOL1_DEV"
format_if_needed "$VOL2_DEV"

###############################################################################
# Step 4) Gather UUIDs, update /etc/fstab
###############################################################################
echo ""
echo "[INFO] Step 4: Gathering UUIDs, adding lines to /etc/fstab..."

VOL1_UUID=$(blkid -s UUID -o value "$VOL1_DEV" || true)
VOL2_UUID=$(blkid -s UUID -o value "$VOL2_DEV" || true)
if [ -z "$VOL1_UUID" ] || [ -z "$VOL2_UUID" ]; then
  echo "[ERROR] Could not retrieve UUID for $VOL1_DEV or $VOL2_DEV."
  exit 1
fi

# Remove any old references by these UUIDs
sed -i "\|$VOL1_UUID|d" /etc/fstab || true
sed -i "\|$VOL2_UUID|d" /etc/fstab || true

{
  echo ""
  echo "# Added by setup_two_volumes.sh on $(date)"
  echo "UUID=$VOL1_UUID  $VOL1_MOUNT  $FILESYSTEM_TYPE  defaults,nofail,discard 0 0"
  echo "UUID=$VOL2_UUID  $VOL2_MOUNT  $FILESYSTEM_TYPE  defaults,nofail,discard 0 0"
} >> /etc/fstab

echo "[INFO] Wrote new lines to /etc/fstab referencing UUIDs:"
echo "      $VOL1_UUID -> $VOL1_MOUNT"
echo "      $VOL2_UUID -> $VOL2_MOUNT"

###############################################################################
# Step 5) Reload systemd, mount -a
###############################################################################
echo ""
echo "[INFO] Reloading systemd daemon to see new /etc/fstab..."
systemctl daemon-reload

echo "[INFO] Running 'mount -a' to mount all fstab entries..."
mount -a || {
  echo "[ERROR] mount -a failed. Check /etc/fstab or syslog."
  exit 1
}

echo ""
echo "[INFO] Setup complete! Current mount usage for /mnt*..."
df -h | grep /mnt || true

echo ""
echo "[INFO] Done! On reboot, volumes will auto-mount. Enjoy."
