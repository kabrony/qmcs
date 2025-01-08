#!/usr/bin/env bash
#
# proceed_autoscript.sh
# Executes a streamlined sequence of maintenance steps with minimal output.
# No parameters needed; just run './proceed_autoscript.sh'.

LOGFILE="proceed_autoscript.log"
echo "[INFO] Running proceed_autoscript.sh..." | tee -a "$LOGFILE"

# 1) Minor Docker cleanup
echo "[STEP 1] Docker prune" | tee -a "$LOGFILE"
docker system prune -af >> "$LOGFILE" 2>&1

# 2) Attempt daily maintenance (if script exists)
DAILY_SCRIPT="daily_repo_maintenance.py"
if [[ -f "$DAILY_SCRIPT" ]]; then
  echo "[STEP 2] Running daily_repo_maintenance.py" | tee -a "$LOGFILE"
  python "$DAILY_SCRIPT" >> "$LOGFILE" 2>&1
else
  echo "[SKIP] $DAILY_SCRIPT not found." | tee -a "$LOGFILE"
fi

# 3) Rebuild & run Docker Compose
echo "[STEP 3] Docker rebuild & run" | tee -a "$LOGFILE"
docker-compose down >> "$LOGFILE" 2>&1
docker-compose build --no-cache >> "$LOGFILE" 2>&1
docker-compose up -d >> "$LOGFILE" 2>&1
echo "[INFO] Containers launched. Check logs for any crash loops." | tee -a "$LOGFILE"

# 4) (Optional) Tail short logs
echo "[STEP 4] Checking short tail logs" | tee -a "$LOGFILE"
docker-compose logs --tail=20 >> "$LOGFILE" 2>&1

# 5) Show final message
echo "[DONE] proceed_autoscript.sh finished. See '$LOGFILE' for details."
