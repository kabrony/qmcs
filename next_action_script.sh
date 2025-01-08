#!/usr/bin/env bash
#
# next_action_script.sh
# A minimal CLI script that performs the next steps in our pipeline:
# 1) Removes the obsolete "version" line from docker-compose.yml (if present).
# 2) Rebuilds and restarts containers in detached mode.
# 3) Shows a short log tail for each container.

LOGFILE="next_action_script.log"

echo "[INFO] next_action_script.sh started..." | tee "$LOGFILE"

# 1) Remove 'version' line from docker-compose.yml if it exists
if grep -q '^version:' docker-compose.yml 2>/dev/null; then
  echo "[INFO] Removing obsolete 'version:' line from docker-compose.yml" | tee -a "$LOGFILE"
  cp docker-compose.yml docker-compose.yml.bak
  sed -i '/^version:/d' docker-compose.yml
else
  echo "[INFO] No 'version:' line found in docker-compose.yml, skipping." | tee -a "$LOGFILE"
fi

# 2) Rebuild containers with no cache & start in detached mode
echo "[INFO] Docker rebuild & up..." | tee -a "$LOGFILE"
docker-compose down || true
docker-compose build --no-cache 2>&1 | tee -a "$LOGFILE"
docker-compose up -d 2>&1 | tee -a "$LOGFILE"

# 3) Tail logs (20 lines) for each running container
echo "[INFO] Checking short logs (20 lines) for each container..." | tee -a "$LOGFILE"
docker ps --format '{{.Names}}' | while read cname; do
  echo "------------------------" | tee -a "$LOGFILE"
  echo "[LOG TAIL for $cname]" | tee -a "$LOGFILE"
  docker logs --tail=20 "$cname" 2>&1 | tee -a "$LOGFILE"
done

echo "[DONE] next_action_script.sh completed. Check '$LOGFILE' for details."
