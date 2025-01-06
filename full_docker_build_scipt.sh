#!/usr/bin/env bash
#
# full_docker_build_script.sh
#
# 1) Stops & removes any old containers/volumes from docker-compose.yml
# 2) Backs up docker-compose.yml -> docker-compose.yml.bak
# 3) Comments out all "container_name:" lines (avoiding name conflicts)
# 4) (Optionally) prunes Docker build cache & volumes
# 5) Builds and runs services from scratch (no cache)
#
# Usage:
#   chmod +x full_docker_build_script.sh
#   ./full_docker_build_script.sh          # Normal run, no Docker cleanup
#   ./full_docker_build_script.sh --clean  # Also prune build cache & volumes
#
# After run, containers auto-name (no collisions).
# Check with "docker-compose logs -f" or "docker ps".

set -e

# ----------------------------------------------------------------------------
# 0) Optional flags: pass "--clean" to prune Docker build cache & volumes
# ----------------------------------------------------------------------------
CLEAN_DOCKER=false
if [[ "$1" == "--clean" ]]; then
  CLEAN_DOCKER=true
fi

# ----------------------------------------------------------------------------
# 1) Stop & remove old containers/volumes from this project
# ----------------------------------------------------------------------------
echo "[INFO] Stopping & removing old containers..."
docker-compose down --volumes || true

# ----------------------------------------------------------------------------
# 2) Back up docker-compose.yml
# ----------------------------------------------------------------------------
if [[ ! -f "docker-compose.yml" ]]; then
  echo "[ERROR] No docker-compose.yml found in $(pwd). Exiting."
  exit 1
fi
echo "[INFO] Backing up docker-compose.yml -> docker-compose.yml.bak"
cp docker-compose.yml docker-compose.yml.bak

# ----------------------------------------------------------------------------
# 3) Comment out "container_name:" lines
# ----------------------------------------------------------------------------
echo "[INFO] Commenting out all 'container_name:' lines..."
sed -i 's/^\(\s*\)container_name:\s*/\1# container_name: /' docker-compose.yml

# ----------------------------------------------------------------------------
# 4) (Optional) Clean Docker build cache & volumes
# ----------------------------------------------------------------------------
if $CLEAN_DOCKER; then
  echo "[INFO] Pruning Docker build cache..."
  docker builder prune -af || true

  echo "[INFO] Pruning unused Docker volumes..."
  docker volume prune -f || true
else
  echo "[INFO] Docker cleanup skipped. (Use --clean to prune build cache & volumes.)"
fi

# ----------------------------------------------------------------------------
# 5) Build & run (no cache)
# ----------------------------------------------------------------------------
echo "[INFO] Building images with no cache..."
docker-compose build --no-cache

echo "[INFO] Starting containers in detached mode..."
docker-compose up -d

echo "[SUCCESS] Done! Run 'docker-compose logs -f' or 'docker ps' to confirm containers."

