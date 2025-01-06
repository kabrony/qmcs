#!/usr/bin/env bash
set -e

###############################################################################
# UPDATE STACK SCRIPT (Clean Final)
# Purpose:
#   1) Safely load .env (ignoring comment lines).
#   2) Perform apt-based system updates (Ubuntu/Debian).
#   3) Optionally install/update Docker Compose plugin.
#   4) Rebuild containers (no-cache) and pull latest images.
#   5) Wait for containers to become healthy.
#   6) Provide placeholders for logs, secrets, advanced AI/RAG expansions.
###############################################################################

###############################################################################
# STEP 0: SAFE LOAD .ENV (IF AVAILABLE)
###############################################################################
echo "[1/9] Loading environment variables from .env (if exists)..."
if [ -f ".env" ]; then
  while IFS= read -r line; do
    # Skip empty/comment lines
    if [[ -z "$line" || "$line" =~ ^# ]]; then
      continue
    fi
    # Only export lines that have KEY=VALUE
    if [[ "$line" =~ ^[A-Za-z0-9_]+=.* ]]; then
      export "$line"
    fi
  done < .env
  echo "[INFO] .env file loaded (comments & blank lines ignored)."
else
  echo "[WARNING] .env file not found. Ensure environment vars are set or create a .env."
fi

###############################################################################
# STEP 1: SYSTEM UPDATES (UBUNTU/DEBIAN)
###############################################################################
echo "[2/9] Checking system updates..."
# You can remove/comment these if you don’t want to auto-update.
sudo apt-get update -y
sudo apt-get upgrade -y
# Optional:
# sudo apt-get dist-upgrade -y
# sudo apt-get autoremove -y
echo "[INFO] System packages updated (basic)."

###############################################################################
# STEP 2: DOCKER COMPOSE PLUGIN UPDATE (OPTIONAL)
###############################################################################
echo "[3/9] Attempting Docker Compose plugin update..."
# If you're using 'docker compose' plugin approach. If you prefer standalone
# 'docker-compose', comment this out or adapt for the binary approach.
sudo apt-get install docker-compose-plugin -y || true
echo "[INFO] Docker Compose plugin re-installed or up-to-date."

###############################################################################
# STEP 3: CHECK DOCKER & DOCKER COMPOSE VERSIONS
###############################################################################
echo "[4/9] Checking Docker & Docker Compose versions..."
docker --version || echo "[WARNING] Docker not found!"
docker compose version || echo "[WARNING] Docker Compose plugin not found!"

###############################################################################
# STEP 4: REBUILD & UPDATE CONTAINERS
###############################################################################
echo "[5/9] Rebuilding containers (pull latest base images, no cache)..."
docker compose build --pull --no-cache
echo "[INFO] Starting containers in detached mode..."
docker compose up -d

###############################################################################
# STEP 5: WAIT FOR HEALTHY CONTAINERS
###############################################################################
TIMEOUT=60
echo "[6/9] Waiting up to $TIMEOUT seconds for containers to become healthy..."
REQUIRED_SERVICES=("solana_agents" "ragchain_service" "quant_service")
START_TIME=$(date +%s)

while true; do
  ALL_HEALTHY=true
  for svc in "${REQUIRED_SERVICES[@]}"; do
    SERVICE_ID=$(docker compose ps -q "$svc" || true)
    if [ -z "$SERVICE_ID" ]; then
      ALL_HEALTHY=false
      break
    fi
    HEALTH_STATE=$(docker inspect -f '{{.State.Health.Status}}' "$SERVICE_ID" 2>/dev/null || true)
    if [ "$HEALTH_STATE" != "healthy" ]; then
      ALL_HEALTHY=false
      break
    fi
  done

  if [ "$ALL_HEALTHY" = true ]; then
    echo "[INFO] All required services are healthy."
    break
  fi

  ELAPSED=$(( $(date +%s) - START_TIME ))
  if [ "$ELAPSED" -gt "$TIMEOUT" ]; then
    echo "[ERROR] Timeout ($TIMEOUT s) while waiting for containers to become healthy."
    docker compose ps
    echo "[INFO] Check logs or refine your health checks if needed."
    exit 1
  fi

  echo "[INFO] Not all containers healthy yet, retrying in 5s..."
  sleep 5
done

###############################################################################
# STEP 6: LOGGING STRATEGY PLACEHOLDER
###############################################################################
echo "[7/9] (Optional) Integrate advanced logging or monitoring solutions."
# e.g., hooking up logs to a third-party aggregator, or enabling 'docker compose logs -f' in the background.

###############################################################################
# STEP 7: SECRETS MANAGEMENT REMINDER
###############################################################################
echo "[8/9] Ensure .env is not committed if it contains private keys. Consider vault solutions."

###############################################################################
# STEP 8: AI / RAG / QUANT EXPANSION
###############################################################################
echo "[9/9] Potential expansions for advanced AI or RAG logic:"
echo " - Integrate LLM APIs (OpenAI, local models) in ragchain_service."
echo " - Enhance quant_service with chain data from solana_agents, advanced analytics, etc."
echo " - Expand health checks for newly added endpoints or services."

echo "---------------------------------------------------------------------"
echo "[INFO] Update stack script finished successfully!"
echo "All containers are up-to-date and healthy. Logs available: 'docker compose logs <service>'."
