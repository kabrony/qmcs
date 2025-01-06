#!/usr/bin/env bash
#
# master_script.sh
#
# 1) Stop & remove old containers in this project
# 2) (Optional) Full cleanup of dangling images/volumes
# 3) Build & run only the services we actually need
#
# Usage:
#   chmod +x master_script.sh
#   ./master_script.sh [service1 service2 ...]
#
# Examples:
#   ./master_script.sh openai_service solana_agents
#   ./master_script.sh quant_service ragchain_service
#
# If you run it with no arguments, it will bring up ALL services.

set -e

echo "[INFO] Stopping and removing old containers..."
docker-compose down

# Uncomment the following line if you want to prune unused images, containers, and volumes:
# docker system prune -af --volumes

echo "[INFO] Rebuilding images (no cache)..."
docker-compose build --no-cache

if [ $# -eq 0 ]; then
  echo "[INFO] No service specified. Bringing up ALL services."
  docker-compose up -d
else
  echo "[INFO] Bringing up only these services: $@"
  docker-compose up -d "$@"
fi

echo "[SUCCESS] Done. Use 'docker-compose logs -f' or 'docker-compose ps' to monitor."
