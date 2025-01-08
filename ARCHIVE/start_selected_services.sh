#!/usr/bin/env bash
#
# start_selected_services.sh
#
# Usage:
#   ./start_selected_services.sh openai_service solana_agents ...
#   or leave blank to start ALL services in docker-compose.yml

# 1) Navigate to the ~/qmcs folder (where docker-compose.yml is)
cd ~/qmcs || {
  echo "[ERROR] ~/qmcs not found!"
  exit 1
}

# 2) Build & run
if [ $# -eq 0 ]; then
  echo "[INFO] No services listed. Bringing up ALL services..."
  docker-compose up --build -d
else
  echo "[INFO] Bringing up only these services: $@"
  docker-compose up --build -d "$@"
fi
