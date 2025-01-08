#!/usr/bin/env bash
set -euo pipefail
LOG="remove_invalid_syntax.log"
echo "[INFO] Starting remove_invalid_syntax.sh..." | tee "$LOG"

SERVICES_MAIN_FILES=(
  "ragchain_service/main.py"
  "quant_service/main.py"
  "openai_service/main.py"
  "argus_service/main.py"
  "oracle_service/main.py"
  "solana_agents/index.js"
)

# Remove lines starting with '//' in Python or Node code
for f in "${SERVICES_MAIN_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    echo "[INFO] Checking $f for lines starting with '//'..." | tee -a "$LOG"
    cp "$f" "$f.bak"
    sed -i '/^[[:space:]]*\/\//d' "$f"
    echo "[INFO] Cleaned $f. Backup: $f.bak" | tee -a "$LOG"
  fi
done

# Remove lines with 'async function' in Python files
for f in "${SERVICES_MAIN_FILES[@]}"; do
  if [[ "$f" == *".py" && -f "$f" ]]; then
    echo "[INFO] Checking $f for 'async function' lines..." | tee -a "$LOG"
    cp "$f" "$f.bak"
    sed -i '/async function/d' "$f"
    echo "[INFO] Cleaned $f. Backup: $f.bak" | tee -a "$LOG"
  fi
done

# Remove lines with "console.log" in Python
for f in "${SERVICES_MAIN_FILES[@]}"; do
  if [[ "$f" == *".py" && -f "$f" ]]; then
    sed -i '/console.log/d' "$f"
  fi
done

# Also remove any Node async usage in index.js incorrectly placed
if [[ -f "solana_agents/index.js" ]]; then
  sed -i 's/const signature = await/\/\/ const signature = (REMOVED_AWAIT)/g' "solana_agents/index.js"
fi

echo "[INFO] remove_invalid_syntax.sh complete. Check '$LOG' for details."
