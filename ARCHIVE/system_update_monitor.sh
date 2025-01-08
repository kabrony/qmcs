#!/usr/bin/env bash
set -e  # Exit on first error

# -----------------------
# Root Check
# -----------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (or with sudo). Try: sudo $0"
  exit 1
fi

# ------------------------------------------------------
#  Color Logging Helpers
# ------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO] $*${NC}"; }
warn()  { echo -e "${YELLOW}[WARN] $*${NC}"; }
err()   { echo -e "${RED}[ERROR] $*${NC}"; }

# ------------------------------------------------------
#  1. Update & Upgrade
# ------------------------------------------------------
info "Starting system update check..."
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y  # Ensures major upgrades (including kernel, etc.)

# ------------------------------------------------------
#  2. Check if Reboot is Required
# ------------------------------------------------------
if [ -f /var/run/reboot-required ]; then
  warn "A system reboot is required. This is usually due to a kernel update or major library update."
  # Optionally uncomment this line to automatically reboot:
  # reboot
fi

# ------------------------------------------------------
#  3. Basic System Monitoring
# ------------------------------------------------------
info "Gathering system resource usage..."

# 3a) CPU Load (last 1, 5, 15 minutes)
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1" "$2" "$3}')
info "CPU Load Averages (1/5/15 min): $LOAD_AVG"

# 3b) Memory Usage
MEMORY_USAGE=$(free -m | awk '/Mem:/{print $3 "MB used / " $2 "MB total (" $3*100/$2 "%)"}')
info "Memory Usage: $MEMORY_USAGE"

# 3c) Swap Usage
SWAP_USAGE=$(free -m | awk '/Swap:/{print $3 "MB used / " $2 "MB total (" $3*100/$2 "%)"}')
info "Swap Usage: $SWAP_USAGE"

# 3d) Disk Usage (root partition)
DISK_USAGE=$(df -h / | awk 'NR==2{print $5 " used (on /)"}')
info "Disk Usage /: $DISK_USAGE"

DISK_PERCENT=$(echo "$DISK_USAGE" | sed 's/%.*//')
if [ "$DISK_PERCENT" -gt 90 ]; then
  warn "Disk usage is above 90%! Consider cleaning up or expanding storage."
fi

# ------------------------------------------------------
#  4. Done
# ------------------------------------------------------
info "system_update_monitor.sh completed successfully!"
