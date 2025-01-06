#!/usr/bin/env bash
set -e

# We'll remove or comment out the lines that force the script to run as root.
# 1) The block around:
#    if [ "$(id -u)" -ne 0 ]; then
#      echo "[ERROR] Must be run as root (or with sudo)."
#      exit 1
#    fi

sed -i '/Root check/,/fi/d' final_extreme_monitor_v4.sh

echo "[INFO] Removed root check from final_extreme_monitor_v4.sh."
