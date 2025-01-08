#!/usr/bin/env bash
##############################################################################
# all_in_one_debug.sh
#
# Purpose:
#   - Print out system info (docker, python versions).
#   - Dump Docker logs for key services.
#   - Cat local Dockerfiles & code (main.py, requirements.txt, etc.).
#   - Cat code from inside containers (/app/main.py, requirements.txt, etc.).
#   - Do 'pip freeze' locally & in each container (if Python available).
#   - Summarize any "ModuleNotFoundError" or "No module named" lines, plus "error".
#
# Usage:
#   chmod +x all_in_one_debug.sh
#   ./all_in_one_debug.sh
#
# Explanation:
#   This script captures all raw output into a temporary file ($TMP_RAW), then
#   appends that entire file to the final $REPORT_FILE. That prevents the dreaded:
#       "grep: input file is also the output"
#   when we do our searches for suspicious lines.
##############################################################################

################### CONFIGURE THESE FOR YOUR ENVIRONMENT #####################

# Docker Compose service names to dump logs and introspect
SERVICES=(
  "argus_service"
  "oracle_service"
  "openai_service"
  "quant_service"
  "ragchain_service"
  "qmcs-solana_agents"
)

# Dockerfiles you want to cat locally
DOCKERFILES=(
  "Dockerfile"
  "argus_service/Dockerfile"
  "oracle_service/Dockerfile"
  "openai_service/Dockerfile"
  "quant_service/Dockerfile"
  "ragchain_service/Dockerfile"
  "solana_agents/Dockerfile"
)

# Subfolders that might have main.py, requirements.txt, etc.
LOCAL_FOLDERS=(
  "argus_service"
  "oracle_service"
  "openai_service"
  "quant_service"
  "ragchain_service"
  "solana_agents"
)

# Final consolidated report
REPORT_FILE="all_in_one_debug_report.txt"

# Temporary file for raw output
TMP_RAW="/tmp/debug_raw.log"

##############################################################################

# Start fresh
> "$REPORT_FILE"
> "$TMP_RAW"

echo "=========== [all_in_one_debug.sh] STARTING DEBUG SCRIPT ===========" | tee -a "$REPORT_FILE"
echo "See '$REPORT_FILE' for the combined output." | tee -a "$REPORT_FILE"
echo "-----------------------------------------------------------" | tee -a "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

############################
# 1) Basic environment info
############################
{
  echo "[1/8] Basic Environment Info"
  date
  echo ""
  echo "[INFO] Docker version:"
  docker --version || echo "(docker not installed?)"
  echo ""

  echo "[INFO] Docker Compose version:"
  docker-compose --version || echo "(docker-compose not installed?)"
  echo ""

  echo "[INFO] Python version (local):"
  python3 --version 2>&1
  echo ""

  echo "[INFO] OS Info (uname -a):"
  uname -a
  echo ""
} >> "$TMP_RAW"


############################
# 2) Docker Compose logs
############################
{
  echo "===================================="
  echo "[2/8] Docker Logs (last 50 lines)"
  echo "===================================="
  for svc in "${SERVICES[@]}"; do
    echo "-----------------------------------------"
    echo "[SERVICE: $svc] logs"
    echo "-----------------------------------------"
    docker-compose logs --no-color --tail=50 "$svc" 2>&1 || {
      echo "[WARN] No logs for $svc (not running?)."
    }
    echo ""
  done
} >> "$TMP_RAW"


############################
# 3) Local Dockerfiles
############################
{
  echo "===================================="
  echo "[3/8] Local Dockerfiles"
  echo "===================================="
  for df in "${DOCKERFILES[@]}"; do
    echo "-----------------------------------------"
    echo "[LOCAL Dockerfile]: $df"
    echo "-----------------------------------------"
    if [[ -f "$df" ]]; then
      cat "$df"
    else
      echo "[WARN] File not found: $df"
    fi
    echo ""
  done
} >> "$TMP_RAW"


############################
# 4) Local code files
############################
{
  echo "===================================="
  echo "[4/8] Local main.py, index.js, requirements.txt"
  echo "===================================="
  for folder in "${LOCAL_FOLDERS[@]}"; do
    echo "-----------------------------------------"
    echo "[FOLDER: $folder]"
    echo "-----------------------------------------"

    # If it has a main.py, cat it
    if [[ -f "$folder/main.py" ]]; then
      echo "==> $folder/main.py:"
      cat "$folder/main.py"
    else
      echo "[WARN] No main.py in $folder"
    fi
    echo ""

    # If it has an index.js, cat it
    if [[ -f "$folder/index.js" ]]; then
      echo "==> $folder/index.js:"
      cat "$folder/index.js"
    else
      echo "[WARN] No index.js in $folder"
    fi
    echo ""

    # If it has requirements
    if [[ -f "$folder/requirements.txt" ]]; then
      echo "==> $folder/requirements.txt:"
      cat "$folder/requirements.txt"
    else
      echo "[WARN] No requirements.txt in $folder"
    fi
    echo ""
  done
} >> "$TMP_RAW"


############################
# 5) Container-based code
############################
{
  echo "===================================="
  echo "[5/8] Container-based code (main.py, requirements.txt)"
  echo "===================================="
  for svc in "${SERVICES[@]}"; do
    echo "-----------------------------------------"
    echo "[Container: $svc]"
    echo "-----------------------------------------"
    # Attempt /app/main.py
    echo ">> /app/main.py:"
    docker exec "$svc" cat /app/main.py 2>/dev/null || echo "[WARN] /app/main.py not found in $svc"
    echo ""

    # Attempt /app/requirements.txt
    echo ">> /app/requirements.txt:"
    docker exec "$svc" cat /app/requirements.txt 2>/dev/null || echo "[WARN] /app/requirements.txt not found in $svc"
    echo ""
  done
} >> "$TMP_RAW"


############################
# 6) pip freeze
############################
{
  echo "===================================="
  echo "[6/8] pip freeze (local + containers)"
  echo "===================================="

  echo "[Local pip freeze]"
  pip freeze 2>&1 || echo "[WARN] local pip freeze failed"
  echo ""

  for svc in "${SERVICES[@]}"; do
    echo "-----------------------------------------"
    echo "[Container: $svc] pip freeze"
    echo "-----------------------------------------"
    docker exec "$svc" pip freeze 2>/dev/null || echo "[WARN] pip freeze not available in $svc"
    echo ""
  done
} >> "$TMP_RAW"


############################
# 7) Summarize Key Errors
############################
{
  echo "===================================="
  echo "[7/8] Searching for Errors in Logs"
  echo "===================================="
  echo "(We'll do the searches AFTER we append $TMP_RAW to $REPORT_FILE.)"
  echo ""
} >> "$TMP_RAW"


############################
# 8) Append raw => final, then grep
############################
cat "$TMP_RAW" >> "$REPORT_FILE"

{
  echo "===================================="
  echo "[8/8] Searching for 'ModuleNotFoundError', 'No module named', 'error'"
  echo "===================================="

  # Search the temporary raw file, not the final report
  echo "------- Potential ModuleNotFound / No module named lines -------"
  grep -Ei "ModuleNotFoundError|No module named" "$TMP_RAW" || echo "(No lines found)"

  echo ""
  echo "------- Searching for lines with 'error' (case-insensitive) -------"
  grep -i "error" "$TMP_RAW" || echo "(No lines with 'error' found.)"

  echo ""
  echo "[DONE] Debugging script finished. Combined report in '$REPORT_FILE'."
} >> "$REPORT_FILE"

# Clean up
rm -f "$TMP_RAW"
