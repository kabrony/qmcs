#!/usr/bin/env bash
#
# safe_openai_upgrade.sh
#
# Ensures we ONLY install or upgrade OpenAI—NEVER uninstall it.
# 1) If openai is missing, it installs it.
# 2) If installed but <1.0.0, it upgrades it.
# 3) Otherwise, it does nothing (no uninstall).
#
# Usage:
#   chmod +x safe_openai_upgrade.sh
#   ./safe_openai_upgrade.sh
#

set -e  # Exit on errors

# 0) Check if 'packaging' is installed, if not, install it
if ! python -c "import packaging" 2>/dev/null; then
  echo "[WARN] 'packaging' module not found. Installing..."
  pip install --no-cache-dir packaging
  echo "[DONE] Installed 'packaging'!"
fi

echo "[CHECK] Checking if 'openai' is installed..."
if python -c "import openai" 2>/dev/null; then
  # If we’re here, 'openai' is installed
  echo "[INFO] 'openai' is installed. Checking version..."

  # Extract the installed version
  installed_ver=$(python -c "import openai; print(openai.__version__)")

  echo "[INFO] Detected openai version: $installed_ver"

  # Compare versions using 'packaging'
  python -c "
from packaging.version import Version
import sys

req_version = Version('1.0.0')
current_version = Version('$installed_ver')

if current_version < req_version:
    sys.exit(0)  # means we should upgrade
else:
    sys.exit(1)  # means no upgrade needed
" && should_upgrade="yes" || should_upgrade="no"

  if [ "$should_upgrade" = "yes" ]; then
    echo "[INFO] 'openai' version is <1.0.0. Upgrading..."
    pip install --no-cache-dir --upgrade openai
    echo "[DONE] Upgraded 'openai'!"
  else
    echo "[INFO] 'openai' version is already >=1.0.0. No upgrade needed."
  fi

else
  # 'openai' is not installed
  echo "[WARN] 'openai' is missing. Installing from scratch..."
  pip install --no-cache-dir openai
  echo "[DONE] Installed 'openai' for the first time!"
fi

echo "[SUCCESS] No uninstall steps performed — script completed."
