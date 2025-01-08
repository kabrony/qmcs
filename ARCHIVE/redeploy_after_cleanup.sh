#!/usr/bin/env bash
#
# redeploy_after_cleanup.sh
# Rebuilds images (no cache) and restarts containers after removing invalid '//' lines.
# Usage: ./redeploy_after_cleanup.sh

LOGFILE="redeploy_after_cleanup.log"
echo "[INFO] Starting redeploy_after_cleanup.sh..." | tee -a "$LOGFILE"

echo "[STEP 1] Stopping any running containers..." | tee -a "$LOGFILE"
docker-compose down || true

echo "[STEP 2] Rebuilding Docker images with --no-cache..." | tee -a "$LOGFILE"
docker-compose build --no-cache 2>&1 | tee -a "$LOGFILE"
if [[ "${PIPESTATUS[0]}" != "0" ]]; then
  echo "[ERROR] Build step failed. Check $LOGFILE for details." | tee -a "$LOGFILE"
  exit 1
fi

echo "[STEP 3] Starting containers in detached mode..." | tee -a "$LOGFILE"
docker-compose up -d 2>&1 | tee -a "$LOGFILE"
echo "[INFO] Compose up completed. Checking short logs..."

echo "[STEP 4] Short tail logs (last 20 lines each)..." | tee -a "$LOGFILE"
docker-compose logs --tail=20 2>&1 | tee -a "$LOGFILE"

echo "[DONE] redeploy_after_cleanup.sh finished. Review $LOGFILE and container logs for details."
