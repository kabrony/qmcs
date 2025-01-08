#!/usr/bin/env bash
#
# fix_container_conflict.sh
#
# A script to force-remove old containers (quant_service, ragchain_service,
# solana_agents, local_mongo) that may cause conflicts. Then rebuild
# with --no-cache, and finally run docker-compose up -d again.

LOGFILE="fix_container_conflict.log"
echo "[INFO] Starting fix_container_conflict.sh..." | tee "$LOGFILE"

# 1) Stop & remove any old containers by these names
CONTAINERS=("quant_service" "ragchain_service" "solana_agents" "local_mongo")
for cname in "${CONTAINERS[@]}"; do
  echo "[INFO] Checking if container '$cname' exists..." | tee -a "$LOGFILE"
  if docker ps -a --format '{{.Names}}' | grep -q "^$cname\$"; then
    echo "[INFO] Removing old container '$cname'..." | tee -a "$LOGFILE"
    docker rm -f "$cname" 2>&1 | tee -a "$LOGFILE"
  else
    echo "[INFO] Container '$cname' not found. Skipping." | tee -a "$LOGFILE"
  fi
done

# 2) Rebuild all Docker images without using cache
echo "[INFO] Rebuilding images with --no-cache..." | tee -a "$LOGFILE"
docker-compose build --no-cache 2>&1 | tee -a "$LOGFILE"

# 3) Start containers in detached mode
echo "[INFO] Starting containers in detached mode..." | tee -a "$LOGFILE"
docker-compose up -d 2>&1 | tee -a "$LOGFILE"

echo "[INFO] Done. Check $LOGFILE for full output."
