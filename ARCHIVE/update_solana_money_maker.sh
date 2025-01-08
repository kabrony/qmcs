#!/usr/bin/env bash
set -e

###############################################################################
# UPDATE_SOLANA_MONEY_MAKER.SH - ALWAYS-RUNNING + ADVANCED LOGIC
#
# Features:
#  1) Load .env for keys (Solana, OPENAI, TAVILY, etc.).
#  2) Optional apt-get updates for Ubuntu.
#  3) Use docker-compose (dash) v2 (no plugin confusion).
#  4) Pull images (optional), build --no-cache, up -d containers.
#  5) Capture last 100 lines of logs => logs_startup.txt, grep for errors.
#  6) Wait for containers to be healthy, partial progress printed.
#  7) Quick memory usage check (docker stats --no-stream).
#  8) Optional ephemeral logic (chain_of_thought.py).
#  9) Optional multi-LLM expansions (token_management.py).
#  10) Containers use 'restart: always' so they remain running indefinitely.
###############################################################################

###############################################################################
# STEP 0: LOAD .ENV (IF EXISTS)
###############################################################################
echo "[1/10] Loading environment from .env (if present)..."
if [ -f ".env" ]; then
  while IFS= read -r line; do
    # Skip empty lines or lines with '#'
    if [[ -z "$line" || "$line" =~ ^# ]]; then
      continue
    fi
    # Only export lines in KEY=VALUE form
    if [[ "$line" =~ ^[A-Za-z0-9_]+=.* ]]; then
      export "$line"
    fi
  done < .env
  echo "[INFO] .env loaded. (E.g., OPENAI_API_KEY, TAVILY_API_KEY, MONGO_DETAILS, etc.)"
else
  echo "[WARNING] No .env file found. Proceeding without environment variables."
fi

###############################################################################
# STEP 1: (OPTIONAL) SYSTEM UPDATES
###############################################################################
echo "[2/10] (Optional) Updating Ubuntu-based packages..."
sudo apt-get update -y
sudo apt-get upgrade -y
echo "[INFO] System packages updated."

###############################################################################
# STEP 2: FORCE DOCKER-COMPOSE (DASH) V2
###############################################################################
echo "[3/10] Ensuring docker-compose (dash) v2..."
composeBinary="docker-compose"

if ! command -v docker-compose &> /dev/null; then
  echo "[ERROR] 'docker-compose' not found. Install standalone Compose v2."
  exit 1
fi

dcVer="$(docker-compose version 2>&1 || true)"
if ! echo "$dcVer" | grep -Eq 'version.*(v)?2'; then
  echo "[WARNING] 'docker-compose' might be v1. We'll try anyway."
else
  echo "[INFO] Found Docker Compose v2."
fi

declare -a cCmd=("$composeBinary")

###############################################################################
# STEP 3: PULL, BUILD --NO-CACHE, UP -D
###############################################################################
echo "[4/10] Pulling images (optional), building no-cache, up -d..."

echo "[INFO] Pulling base images..."
"${cCmd[@]}" pull || true

echo "[INFO] Building containers with no cache..."
"${cCmd[@]}" build --no-cache

echo "[INFO] Starting containers in detached mode..."
"${cCmd[@]}" up -d

###############################################################################
# STEP 4: LOG CAPTURE & ERROR SEARCH
###############################################################################
echo "[5/10] logs_startup.txt capturing last 100 lines..."
"${cCmd[@]}" logs --tail=100 > logs_startup.txt || true
echo "[INFO] Searching logs_startup.txt for errors/warnings..."
grep -iE '(error|exception|warning|traceback)' logs_startup.txt || true

###############################################################################
# STEP 5: WAIT FOR HEALTH
###############################################################################
TIMEOUT=60
echo "[6/10] Waiting up to $TIMEOUT seconds for containers to be healthy..."

REQUIRED_SERVICES=("solana_agents" "quant_service" "ragchain_service")
START_TIME=$(date +%s)

while true; do
  ALL_HEALTHY=true
  UNHEALTHY_LIST=()

  for svc in "${REQUIRED_SERVICES[@]}"; do
    CID=$("${cCmd[@]}" ps -q "$svc" 2>/dev/null || true)
    if [ -z "$CID" ]; then
      ALL_HEALTHY=false
      UNHEALTHY_LIST+=("${svc}(NoID)")
      continue
    fi
    HSTATE=$(docker inspect -f '{{.State.Health.Status}}' "$CID" 2>/dev/null || true)
    if [ "$HSTATE" != "healthy" ]; then
      ALL_HEALTHY=false
      UNHEALTHY_LIST+=("${svc}($HSTATE)")
    fi
  done

  if [ "$ALL_HEALTHY" = true ]; then
    echo "[INFO] All required services are healthy."
    break
  fi

  ELAPSED=$(( $(date +%s) - START_TIME ))
  if [ "$ELAPSED" -gt "$TIMEOUT" ]; then
    echo "[ERROR] Timeout ($TIMEOUT s). Unhealthy: ${UNHEALTHY_LIST[*]}"
    "${cCmd[@]}" ps
    exit 1
  fi

  echo "[INFO] Not all containers healthy yet: ${UNHEALTHY_LIST[*]}"
  echo "[INFO] Retrying in 5s..."
  sleep 5
done

###############################################################################
# STEP 6: MEMORY USAGE SNAPSHOT
###############################################################################
echo "[7/10] Checking memory usage (docker stats --no-stream)..."
docker stats --no-stream || true

###############################################################################
# STEP 7: EPHEMERAL CHAIN-OF-THOUGHT (OPTIONAL)
###############################################################################
echo "[8/10] Checking for scripts/chain_of_thought.py..."
if [ -f "scripts/chain_of_thought.py" ]; then
  echo "[INFO] Running ephemeral chain_of_thought.py..."
  python3 scripts/chain_of_thought.py \
    --rag-url http://localhost:5000 \
    --quant-url http://localhost:7000 \
    --temp-file /tmp/chain_of_thought.json
else
  echo "[WARNING] scripts/chain_of_thought.py not found. Skipping ephemeral logic."
fi

###############################################################################
# STEP 8: MULTI-LLM TOKEN MANAGEMENT
###############################################################################
echo "[9/10] Checking for scripts/token_management.py..."
if [ -f "scripts/token_management.py" ]; then
  echo "[INFO] Running multi-LLM token management..."
  python3 scripts/token_management.py \
    --openai-key "${OPENAI_API_KEY:-}" \
    --gemini-key "${GEMINI_API_KEY:-}" \
    --tavily-key "${TAVILY_API_KEY:-}" \
    --temp-file /tmp/chain_of_thought.json \
    --cost-threshold 0.8 \
    --complexity-threshold 0.8
else
  echo "[WARNING] scripts/token_management.py not found. Skipping multi-LLM logic."
fi

###############################################################################
# STEP 9: DONE
###############################################################################
echo "[10/10] update_solana_money_maker.sh finished successfully!"
echo "All containers use 'restart: always' in docker-compose.yml, so they keep running indefinitely."
echo "Check logs with 'docker-compose logs -f <service>' (e.g., solana_agents)."
