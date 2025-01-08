#!/usr/bin/env bash
set -e

# This patch comments out any line that starts with apt-get
# or references apt-get dist-upgrade/autoremove/autoclean, etc.

sed -i 's/^[ \t]*apt-get /#&/' final_extreme_monitor_v4.sh
sed -i 's/^[ \t]*apt-get/#&/' final_extreme_monitor_v4.sh
sed -i 's/^[ \t]*apt-get/#&/' final_extreme_monitor_v4.sh

echo "[INFO] Commented out apt-get lines in final_extreme_monitor_v4.sh."
