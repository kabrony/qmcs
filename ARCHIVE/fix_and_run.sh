#!/usr/bin/env bash

LOGFILE="fix_and_run.log"
echo "[INFO] Starting fix_and_run.sh..." | tee "$LOGFILE"

COMMON_FIX_SCRIPT=$(cat <<'END'
#!/usr/bin/env bash

LOGFILE="fix_common_syntax_issues.log"
echo "[INFO] Starting fix_common_syntax_issues.sh..." | tee "$LOGFILE"

PYTHON_FILES=(
  "quant_service/main.py"
  "ragchain_service/main.py"
  "openai_service/main.py"
  "argus_service/main.py"
  "oracle_service/main.py"
)

NODE_FILE="solana_agents/index.js"

# 1) Fix missing closing parenthesis in Python env lines
for pyfile in "${PYTHON_FILES[@]}"; do
  if [[ -f "$pyfile" ]]; then
    echo "[INFO] Checking $pyfile for env line missing closing parenthesis..." | tee -a "$LOGFILE"
    cp "$pyfile" "$pyfile.bak"
    # For lines like:
    #   SOLANA_AGENTS_URL = os.getenv("SOLANA_AGENTS_URL","http://solana_agents:5106"
    # we add a trailing ')' if line ends without one.
    sed -i -E 's/(os\.getenv\([^)]*),$/\1)/' "$pyfile"
  else
    echo "[WARN] $pyfile not found. Skipping." | tee -a "$LOGFILE"
  fi
done

echo "[DONE] fix_common_syntax_issues.sh completed. Check '$LOGFILE' for details."
END
)

echo "[INFO] Writing corrected fix_common_syntax_issues.sh..." | tee -a "$LOGFILE"
echo "$COMMON_FIX_SCRIPT" > fix_common_syntax_issues.sh
chmod +x fix_common_syntax_issues.sh

echo "[INFO] Patching quant_service/main.py for missing parenthesis..." | tee -a "$LOGFILE"
sed -i 's/os\.getenv("SOLANA_AGENTS_URL","http:\/\/solana_agents:5106"/os\.getenv("SOLANA_AGENTS_URL","http:\/\/solana_agents:5106")/' quant_service/main.py

echo "[INFO] Running fix_common_syntax_issues.sh..." | tee -a "$LOGFILE"
./fix_common_syntax_issues.sh 2>&1 | tee -a "$LOGFILE"

if [[ -f "unify_build_run_check.sh" ]]; then
  echo "[INFO] Running unify_build_run_check.sh..." | tee -a "$LOGFILE"
  chmod +x unify_build_run_check.sh
  ./unify_build_run_check.sh 2>&1 | tee -a "$LOGFILE"
else
  echo "[WARN] unify_build_run_check.sh not found. Please run docker-compose build/up manually." | tee -a "$LOGFILE"
fi

echo "[INFO] Done. Now run:  chmod +x fix_and_run.sh && ./fix_and_run.sh" | tee -a "$LOGFILE"
echo "[DONE] fix_and_run.sh completed. See '$LOGFILE' for details." | tee "$LOGFILE"
