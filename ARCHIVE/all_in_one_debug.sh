#!/usr/bin/env bash
##############################################################################
# all_in_one_debug.sh
#
# Purpose:
#   1. Print out key environment info (docker-compose version, local Python, etc.)
#   2. Dump Docker logs for all relevant containers (like ragchain_service, openai_service, etc.).
#   3. Cat Dockerfiles, main.py, requirements.txt from each subdirectory (both local and in containers).
#   4. Attempt to check for missing Python dependencies (both locally and in containers).
#   5. Summarize known issues, such as "No module named X" if found in logs.
#
# Usage:
#   chmod +x all_in_one_debug.sh
#   ./all_in_one_debug.sh
#
#   (You can run it from your "qmcs" folder or any root folder that has docker-compose.yml)
##############################################################################

# --- CONFIGURATION: Adjust if your service names or code paths differ
SERVICES=(
  "argus_service"
  "oracle_service"
  "openai_service"
  "quant_service"
  "ragchain_service"
  "qmcs-solana_agents"
)
LOCAL_PATHS=(
  "argus_service"
  "oracle_service"
  "openai_service"
  "quant_service"
  "ragchain_service"
  "solana_agents"
)
DOCKERFILE_PATHS=(
  "Dockerfile"
  "argus_service/Dockerfile"
  "oracle_service/Dockerfile"
  "openai_service/Dockerfile"
  "quant_service/Dockerfile"
  "ragchain_service/Dockerfile"
  "solana_agents/Dockerfile"
)

# The output file where we store everything
REPORT_FILE="all_in_one_debug_report.txt"

# Reset or create the report file
> "$REPORT_FILE"

echo "=========== [all_in_one_debug.sh] STARTING DEBUG SCRIPT ==========="
echo "See '$REPORT_FILE' for the combined output."
echo "-----------------------------------------------------------"

# ----------------------------------------------------------------------
# 1) Basic Environment Checks
# ----------------------------------------------------------------------
{
  echo "==============================================="
  echo "[1/6] Basic System / Docker Info"
  echo "==============================================="
  date
  echo ""

  echo "[INFO] Docker version:"
  docker --version || echo " (Docker not found)"

  echo "[INFO] Docker Compose version:"
  docker-compose --version || echo " (docker-compose not found)"

  echo "[INFO] Python version (local):"
  python3 --version 2>&1

  echo "[INFO] OS Info (uname -a):"
  uname -a
  echo ""

} >> "$REPORT_FILE"

# ----------------------------------------------------------------------
# 2) Docker Logs
# ----------------------------------------------------------------------
{
  echo "==============================================="
  echo "[2/6] Docker Compose Logs for Key Services"
  echo "==============================================="
  for SVC in "${SERVICES[@]}"; do
    echo "-----------------------------------------------------------"
    echo "[LOGS for: $SVC]"
    echo "-----------------------------------------------------------"
    docker-compose logs --no-color --tail=50 "$SVC" 2>&1 || {
      echo "[WARNING] Unable to get logs for service '$SVC'—maybe not running?"
    }
    echo ""
  done
} >> "$REPORT_FILE"

# ----------------------------------------------------------------------
# 3) Cat Dockerfiles, main.py, requirements, etc. from Local
# ----------------------------------------------------------------------
{
  echo "==============================================="
  echo "[3/6] Local Dockerfile / Code Dump"
  echo "==============================================="

  # Dockerfiles
  echo "[3A] Dockerfiles"
  for DF_PATH in "${DOCKERFILE_PATHS[@]}"; do
    echo "-----------------------------------------------------------"
    echo "[DOCKERFILE: $DF_PATH]"
    echo "-----------------------------------------------------------"
    if [[ -f "$DF_PATH" ]]; then
      cat "$DF_PATH"
    else
      echo "[WARNING] $DF_PATH not found locally."
    fi
    echo ""
  done

  # Attempt to cat certain known files in subfolders
  echo "[3B] main.py / requirements.txt in subfolders"
  for p in "${LOCAL_PATHS[@]}"; do
    echo "-----------------------------------------------------------"
    echo "[SUBFOLDER: $p]"
    echo "-----------------------------------------------------------"
    if [[ -f "$p/requirements.txt" ]]; then
      echo "==> $p/requirements.txt:"
      cat "$p/requirements.txt"
      echo ""
    fi
    if [[ -f "$p/main.py" ]]; then
      echo "==> $p/main.py:"
      cat "$p/main.py"
      echo ""
    fi
    if [[ -f "$p/index.js" ]]; then
      echo "==> $p/index.js:"
      cat "$p/index.js"
      echo ""
    fi
  done
} >> "$REPORT_FILE"

# ----------------------------------------------------------------------
# 4) Check inside Docker containers for main.py / requirements
# ----------------------------------------------------------------------
{
  echo "==============================================="
  echo "[4/6] Docker Container File Dumps"
  echo "==============================================="
  for SVC in "${SERVICES[@]}"; do
    echo "-----------------------------------------------------------"
    echo "[Container: $SVC] cat /app/main.py && requirements.txt"
    echo "-----------------------------------------------------------"

    # We'll cat /app/requirements*.txt if present
    docker exec -i "$SVC" sh -c 'cat /app/requirements.txt 2>/dev/null || cat /app/requirements*.txt 2>/dev/null' 2>&1 || echo "[INFO] No /app/requirements in container $SVC."
    echo ""

    # We'll cat /app/main.py if present
    docker exec -i "$SVC" cat /app/main.py 2>&1 || echo "[INFO] No /app/main.py in container $SVC."
    echo ""
  done
} >> "$REPORT_FILE"

# ----------------------------------------------------------------------
# 5) Attempt to detect missing Python packages (locally & in containers)
# ----------------------------------------------------------------------
{
  echo "==============================================="
  echo "[5/6] Checking for Potential Missing Python Dependencies"
  echo "==============================================="
  echo "[local pip freeze]"
  pip freeze 2>/dev/null || echo "[WARNING] Could not run pip freeze locally."

  # Attempt 'pip freeze' inside containers:
  for SVC in "${SERVICES[@]}"; do
    echo ""
    echo "-----------------------------------------------------------"
    echo "[Container: $SVC] pip freeze"
    echo "-----------------------------------------------------------"
    docker exec -i "$SVC" pip freeze 2>/dev/null || echo "[INFO] Could not run pip freeze in container $SVC."
  done

} >> "$REPORT_FILE"

# ----------------------------------------------------------------------
# 6) Summarize Known Errors
# ----------------------------------------------------------------------
{
  echo "==============================================="
  echo "[6/6] Summarize Known Issues from Logs"
  echo "==============================================="
  # We'll just grep for common error patterns in the big file we compiled
  # (like "ModuleNotFoundError", "No module named", "ERROR" lines, etc.)
  echo ""
  echo "[GREP for 'ModuleNotFoundError' or 'No module named']"
  grep -i -E "ModuleNotFoundError|no module named" "$REPORT_FILE" || echo " (No direct 'ModuleNotFoundError' found in this log)."

  echo ""
  echo "[GREP for 'ERROR' lines (case-insensitive)]"
  grep -i "error" "$REPORT_FILE" || echo " (No 'ERROR' lines found)."

  echo ""
  echo "[HINT] If you see something like 'No module named X', you can fix it by installing it in your Dockerfile/requirements."
} >> "$REPORT_FILE"

# Done
echo "[DONE] Debugging script finished. All info appended to '$REPORT_FILE'."
