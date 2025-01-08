#!/usr/bin/env bash
#
# finalize_compose_fixes.sh
# 1) Removes 'version' from docker-compose.yml
# 2) Attempts a fresh build and run
# 3) Shows short logs

LOGFILE="finalize_compose_fixes.log"
echo "[INFO] Starting finalize_compose_fixes.sh..." | tee -a "$LOGFILE"

# 1) Remove any 'version' line from docker-compose.yml, if present.
echo "[STEP 1] Removing 'version' line from docker-compose.yml..." | tee -a "$LOGFILE"
if grep -q '^version:' docker-compose.yml; then
  cp docker-compose.yml docker-compose.yml.bak 2>/dev/null
  sed -i '/^version:/d' docker-compose.yml
  echo "[INFO] Removed 'version:' line. Backup: docker-compose.yml.bak" | tee -a "$LOGFILE"
else
  echo "[SKIP] No 'version:' line found in docker-compose.yml." | tee -a "$LOGFILE"
fi

# 2) Attempt fresh build & run
echo "[STEP 2] Docker compose build & up" | tee -a "$LOGFILE"
docker-compose down >> "$LOGFILE" 2>&1
docker-compose build --no-cache >> "$LOGFILE" 2>&1
docker-compose up -d >> "$LOGFILE" 2>&1
echo "[INFO] Compose up completed. Checking short logs..." | tee -a "$LOGFILE"

# 3) Show short tail logs
echo "[STEP 3] Short tail logs (20 lines each container)" | tee -a "$LOGFILE"
docker-compose logs --tail=20 >> "$LOGFILE" 2>&1

echo "[DONE] finalize_compose_fixes.sh finished. See '$LOGFILE' for details."
