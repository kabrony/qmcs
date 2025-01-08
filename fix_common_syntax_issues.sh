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
