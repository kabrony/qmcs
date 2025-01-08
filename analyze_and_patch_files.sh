#!/usr/bin/env bash
#
# analyze_and_patch_files.sh
#
# This script demonstrates one approach to:
#   1) Recursively find all Python and JavaScript/Node files.
#   2) Attempt a syntax check or compilation step on each file.
#   3) Log any files that fail (so you can fix them).
#   4) (Optional) Apply small auto-patches for trivial issues (like removing partial lines).

LOGFILE="analyze_and_patch_files.log"
echo "[INFO] Starting analyze_and_patch_files.sh..." | tee "$LOGFILE"

ROOT_DIR="." # Adjust if you want a different root, e.g. ~/qmcs

################################################################################
# 1) FIND & ANALYZE PYTHON FILES
#    - We'll use `python -m py_compile` to do a quick syntax check.
################################################################################
echo "" | tee -a "$LOGFILE"
echo "[STEP] Analyzing Python files..." | tee -a "$LOGFILE"

ERROR_COUNT_PY=0
while IFS= read -r -d '' pyfile; do
  echo "  [CHECK] $pyfile" | tee -a "$LOGFILE"
  python -m py_compile "$pyfile" 2>>"$LOGFILE"
  if [[ $? -ne 0 ]]; then
    echo "  [ERROR] Syntax error in $pyfile (see details in $LOGFILE)" | tee -a "$LOGFILE"
    ((ERROR_COUNT_PY++))
  fi
done < <(find "$ROOT_DIR" -type f \( -iname "*.py" \) -print0)

################################################################################
# 2) FIND & ANALYZE JAVASCRIPT / NODE FILES
#    - We'll attempt `node --check file.js` for basic syntax checks.
#      (Requires Node >= 10)
################################################################################
echo "" | tee -a "$LOGFILE"
echo "[STEP] Analyzing Node/JS files..." | tee -a "$LOGFILE"

ERROR_COUNT_JS=0
if command -v node >/dev/null 2>&1; then
  while IFS= read -r -d '' jsfile; do
    echo "  [CHECK] $jsfile" | tee -a "$LOGFILE"
    node --check "$jsfile" 2>>"$LOGFILE"
    if [[ $? -ne 0 ]]; then
      echo "  [ERROR] Syntax error in $jsfile (see details in $LOGFILE)" | tee -a "$LOGFILE"
      ((ERROR_COUNT_JS++))
    fi
  done < <(find "$ROOT_DIR" -type f \( -iname "*.js" -o -iname "*.mjs" -o -iname "*.cjs" \) -print0)
else
  echo "[WARN] 'node' command not found. Skipping JS syntax checks." | tee -a "$LOGFILE"
fi

################################################################################
# 3) (OPTIONAL) Attempt trivial auto-patches
#    Example: remove lines that only have '//' or partial parentheses, etc.
#    NOTE: Use with caution; can break code if not used carefully!
################################################################################
AUTO_FIX=0   # Set to 1 if you want to apply naive fixes
if [[ $AUTO_FIX -eq 1 ]]; then
  echo "" | tee -a "$LOGFILE"
  echo "[STEP] Attempting naive auto-patches..." | tee -a "$LOGFILE"
  
  # Example fix: remove lines that only contain '//' in Python files
  while IFS= read -r -d '' pyfile; do
    echo "  [FIX] Removing lines with only '//' in $pyfile" | tee -a "$LOGFILE"
    sed -i '/^[[:space:]]*\/\/[[:space:]]*$/d' "$pyfile"
  done < <(find "$ROOT_DIR" -type f -iname "*.py" -print0)
  
  # Example fix: remove lines that only contain '(' or ')' in JS files
  while IFS= read -r -d '' jsfile; do
    echo "  [FIX] Removing lines with lone '(' or ')' in $jsfile" | tee -a "$LOGFILE"
    sed -i '/^[[:space:]]*(\s*$/d' "$jsfile"
    sed -i '/^[[:space:]]*)\s*$/d' "$jsfile"
  done < <(find "$ROOT_DIR" -type f \( -iname "*.js" -o -iname "*.mjs" -o -iname "*.cjs" \) -print0)

  echo "[INFO] Auto-patching done. Re-run script to see if syntax errors improved." | tee -a "$LOGFILE"
fi

################################################################################
# 4) SUMMARY
################################################################################
echo "" | tee -a "$LOGFILE"
echo "[SUMMARY]" | tee -a "$LOGFILE"
echo "  Python syntax errors found : $ERROR_COUNT_PY" | tee -a "$LOGFILE"
echo "  JS     syntax errors found : $ERROR_COUNT_JS" | tee -a "$LOGFILE"

if [[ $ERROR_COUNT_PY -eq 0 && $ERROR_COUNT_JS -eq 0 ]]; then
  echo "[DONE] No syntax errors detected. All good!" | tee -a "$LOGFILE"
else
  echo "[DONE] Some files had syntax errors. Check $LOGFILE for details, then fix them manually." | tee -a "$LOGFILE"
fi
