#!/usr/bin/env bash
#
# unify_final_cleanup.sh
# Final script to verify that the unwanted syntax has been removed,
# rebuild Docker images, and bring services up in detached mode.

LOGFILE="unify_final_cleanup.log"

echo "[INFO] Starting unify_final_cleanup.sh..." | tee "$LOGFILE"

echo "[STEP 1] Verifying if Python files still contain invalid syntax..." | tee -a "$LOGFILE"
INVALID_COUNT=$(grep -rnE "//|async function" \
  quant_service/*.py \
  ragchain_service/*.py \
  openai_service/*.py \
  argus_service/*.py \
  oracle_service/*.py \
  2>/dev/null | wc -l)

if [[ "$INVALID_COUNT" -gt 0 ]]; then
  echo "[WARN] Found some lines with invalid syntax. They might cause crashes." | tee -a "$LOGFILE"
  grep -rnE "//|async function" \
    quant_service/*.py \
    ragchain_service/*.py \
    openai_service/*.py \
    argus_service/*.py \
    oracle_service/*.py \
    2>/dev/null | tee -a "$LOGFILE"
  echo "[INFO] Please remove or fix them before proceeding." | tee -a "$LOGFILE"
else
  echo "[OK] No invalid syntax ('//' or 'async function') lines found in Python code." | tee -a "$LOGFILE"
fi

echo "[STEP 2] Rebuilding Docker images..." | tee -a "$LOGFILE"
docker-compose down || true
docker-compose build --no-cache

echo "[STEP 3] Bringing containers up in detached mode..." | tee -a "$LOGFILE"
docker-compose up -d

echo "[STEP 4] Short tail of logs (30 lines each container) to check for any crash loops..." | tee -a "$LOGFILE"
docker-compose logs --tail=30

echo "[DONE] unify_final_cleanup.sh completed. Check '$LOGFILE' for details."
