#!/usr/bin/env bash
#
# remove_async_function_syntax.sh
# Scans Python files (and optionally .js files) to remove lines containing "async function ... {"
# that cause invalid syntax in Python code.

LOGFILE="remove_async_function_syntax.log"
echo "[INFO] Starting remove_async_function_syntax.sh..." | tee "$LOGFILE"

# List of files to check
# Adjust or add more paths if needed
SERVICES_MAIN_FILES=(
  "quant_service/main.py"
  "ragchain_service/main.py"
  "openai_service/main.py"
  "argus_service/main.py"
  "oracle_service/main.py"
  "solana_agents/index.js"
)

for file_path in "${SERVICES_MAIN_FILES[@]}"; do
  if [[ -f "$file_path" ]]; then
    echo "[INFO] Checking $file_path for 'async function' lines..." | tee -a "$LOGFILE"
    # Create a backup first
    cp "$file_path" "$file_path.bak"
    # Remove lines that contain 'async function' which is invalid in Python
    sed -i '/async function .*{/d' "$file_path"
    echo "[INFO] Cleaned $file_path. Backup: $file_path.bak" | tee -a "$LOGFILE"
  else
    echo "[WARN] File not found: $file_path. Skipping..." | tee -a "$LOGFILE"
  fi
done

echo "[INFO] remove_async_function_syntax.sh complete. Check $LOGFILE for details."
