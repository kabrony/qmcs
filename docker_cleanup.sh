#!/usr/bin/env bash
#
# docker_cleanup.sh
#
# This script cleans out Docker build cache and optionally volumes.
# Usage:
#   chmod +x docker_cleanup.sh
#   ./docker_cleanup.sh           # clears build cache only
#   ./docker_cleanup.sh --volumes # also prunes local volumes
#
# Example cron (runs every Sunday at midnight):
#   0 0 * * 0 /path/to/docker_cleanup.sh --volumes >> /var/log/docker_cleanup.log 2>&1

set -e

# Check for a '--volumes' argument
PRUNE_VOLUMES=false
if [[ "$1" == "--volumes" ]]; then
  PRUNE_VOLUMES=true
fi

echo "[INFO] Pruning Docker build cache..."
docker builder prune -af || true

if $PRUNE_VOLUMES; then
  echo "[INFO] Pruning unused Docker volumes..."
  docker volume prune -f || true
else
  echo "[INFO] Skipping volume prune. (Use --volumes to remove volumes.)"
fi

echo "[SUCCESS] Docker cleanup finished."
