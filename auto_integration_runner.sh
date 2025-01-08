#!/usr/bin/env bash
#
# auto_integration_runner.sh
# Attempts to automate each major step from final_integration_steps.sh.

# 0) Preliminary checks
echo "======================================================="
echo "   AUTO INTEGRATION RUNNER - BEGIN"
echo "======================================================="
REPO_DIR="$(pwd)"

# 1) Check environment variables from .env if it exists
echo ""
echo "[1] CHECKING .env (if present)"
if [ -f "${REPO_DIR}/.env" ]; then
  echo "Found .env. Below are a few lines referencing known env names..."
  grep -E 'MYSQL|REDIS|MONGO|SOLANA|OPENAI_API_KEY|GEMINI_API_KEY|DEEPSEEK_API_KEY' "${REPO_DIR}/.env" || echo "[WARN] No matching lines found or no sensitive vars present."
else
  echo "[INFO] No .env file found in ${REPO_DIR}."
fi

# 2) Confirm references to main.py / index.js in each Dockerfile
echo ""
echo "[2] CHECKING DOCKERFILES FOR 'main.py' or 'index.js' references"
dockerfiles=$(find "${REPO_DIR}" -type f -name "Dockerfile")
if [ -z "$dockerfiles" ]; then
  echo "[WARN] No Dockerfiles found under ${REPO_DIR}."
else
  for df in $dockerfiles; do
    echo " -- Checking $df"
    matches=$(grep -E 'main\.py|index\.js' "$df" || true)
    if [ -z "$matches" ]; then
      echo "[WARN] No 'main.py' or 'index.js' found in $df"
    else
      echo "[OK] Found references in $df:"
      echo "$matches"
    fi
  done
fi

# 3) Rebuild & run containers
echo ""
echo "[3] DOCKER-COMPOSE BUILD & UP"
if [ -f "${REPO_DIR}/docker-compose.yml" ]; then
  echo "Stopping existing containers..."
  docker-compose down || echo "[WARN] docker-compose down failed (ok if none running)."

  echo "Building images (no cache)..."
  docker-compose build --no-cache

  echo "Launching containers in detached mode..."
  docker-compose up -d

  echo "Containers started. Checking logs (short tail)..."
  docker-compose logs --tail=50
else
  echo "[ERROR] No docker-compose.yml found in ${REPO_DIR}. Skipping container steps."
fi

# 4) Offer to run local tests
echo ""
echo "[4] OFFERING TO RUN LOCAL TESTS"
found_py_tests="no"
found_node_tests="no"

if [ -d "${REPO_DIR}/tests" ]; then
  # If there's a tests folder, let's attempt pytest
  found_py_tests="yes"
fi

if [ -f "${REPO_DIR}/package.json" ]; then
  # If there's a package.json, let's assume 'npm test'
  found_node_tests="yes"
fi

if [ "$found_py_tests" = "yes" ] || [ "$found_node_tests" = "yes" ]; then
  echo "We found evidence of test structures."
  echo "Would you like to run them now? [y/N]"
  read -r run_tests
  if [[ "$run_tests" =~ ^[Yy]$ ]]; then
    if [ "$found_py_tests" = "yes" ]; then
      echo "[INFO] Running pytest tests..."
      pytest tests || echo "[WARN] Pytest tests encountered errors."
    fi
    if [ "$found_node_tests" = "yes" ]; then
      echo "[INFO] Running 'npm test'..."
      npm test || echo "[WARN] npm test encountered errors."
    fi
  else
    echo "[INFO] Skipped local tests."
  fi
else
  echo "[INFO] No standard test folder or package.json found. Skipping local tests."
fi

# 5) Remind about VOTS Dashboard & EnhancedSystemMonitor
echo ""
echo "[5] VOTS DASHBOARD & MONITORING REMINDER"
echo " - Integrate EnhancedSystemMonitor logs/metrics into VOTS Dashboard or a Gradio-based UI."
echo " - Provide real-time views for performance & alerts (docker logs, metrics)."
echo " - Optionally unify the AI & Solana backtesting pipeline if relevant."

# 6) Daily automation scripts
echo ""
echo "[6] DAILY AUTOMATION SCRIPTS"
echo " - You can add a crontab entry for daily_repo_maintenance.py or daily_oracle_maintenance.py like:"
echo '   0 3 * * * cd ~/qmcs && /usr/bin/python3 daily_repo_maintenance.py >> ~/qmcs/cron_maintenance.log 2>&1'
echo "[INFO] Done. Check 'master_maintenance_script.log' or 'cron_maintenance.log' for issues."

echo ""
echo "======================================================="
echo "   AUTO INTEGRATION RUNNER - END"
echo "======================================================="
