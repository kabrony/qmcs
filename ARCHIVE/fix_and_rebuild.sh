#!/usr/bin/env bash
#
# fix_and_rebuild.sh
#
# 1) Stop & remove old containers from docker-compose.yml (fixing container name conflicts).
# 2) Backs up docker-compose.yml -> docker-compose.yml.bak
# 3) Removes (or comments out) container_name: lines
# 4) Optional cleanup of Docker build cache & volumes
# 5) Rebuild & run all services in docker-compose.yml (no cache)
#
# Usage:
#   chmod +x fix_and_rebuild.sh
#   ./fix_and_rebuild.sh          # Normal run
#   ./fix_and_rebuild.sh --clean  # Also prune build cache & volumes
#

set -e

# ------------------------------------------------------------------------------
# 0) Parse optional --clean flag
# ------------------------------------------------------------------------------
CLEAN_DOCKER=false
if [[ "$1" == "--clean" ]]; then
  CLEAN_DOCKER=true
fi

# ------------------------------------------------------------------------------
# 1) Confirm docker-compose.yml present
# ------------------------------------------------------------------------------
if [[ ! -f "docker-compose.yml" ]]; then
  echo "[ERROR] No docker-compose.yml found in $(pwd). Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------
# 2) Stop & remove old containers/volumes
# ------------------------------------------------------------------------------
echo "[INFO] Stopping & removing old containers..."
docker-compose down --volumes || true

# ------------------------------------------------------------------------------
# 3) Backup your docker-compose.yml
# ------------------------------------------------------------------------------
echo "[INFO] Backing up docker-compose.yml -> docker-compose.yml.bak"
cp docker-compose.yml docker-compose.yml.bak

# ------------------------------------------------------------------------------
# 4) Remove or comment out container_name lines
#    (Pick either removal or comment-out approach)
# ------------------------------------------------------------------------------
# Approach A: Remove container_name lines entirely
# sed -i '/container_name:/d' docker-compose.yml

# Approach B: Comment them out for reference
sed -i 's/^\(\s*\)container_name:\s*/\1# container_name: /' docker-compose.yml

# ------------------------------------------------------------------------------
# 5) (Optional) Clean Docker build cache & volumes
# ------------------------------------------------------------------------------
if $CLEAN_DOCKER; then
  echo "[INFO] Pruning Docker build cache..."
  docker builder prune -af || true

  echo "[INFO] Pruning unused Docker volumes..."
  docker volume prune -f || true
else
  echo "[INFO] Docker cleanup skipped. (Use --clean to prune build cache & volumes.)"
fi

# ------------------------------------------------------------------------------
# 6) Build & run containers from scratch
# ------------------------------------------------------------------------------
echo "[INFO] Building images with no cache..."
docker-compose build --no-cache

echo "[INFO] Starting containers in detached mode..."
docker-compose up -d

echo "[SUCCESS] Done! Run 'docker-compose logs -f' or 'docker ps' to confirm containers."
