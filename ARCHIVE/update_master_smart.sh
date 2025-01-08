#!/usr/bin/env bash
set -e

###############################################################################
# UPDATE + SMART MEMORY MASTER SCRIPT (ADVANCED LOGGING)
#
# Key Points:
#   1) Forces docker-compose (dash) v2 usage (ignoring plugin approach).
#   2) Loads .env, ignoring comments.
#   3) (Optional) auto-updates Ubuntu system packages.
#   4) Pulls images (optional), rebuilds with --no-cache, up -d containers.
#   5) Captures & analyzes logs right after container startup, storing them
#      in logs_startup.txt and grepping for errors.
#   6) Waits for containers to become healthy, printing partial progress
#      so you see which service is still not healthy.
#   7) Provides placeholders for ephemeral memory, Oracle logic, AI-based
#      chain-of-thought expansions, RL loops, etc.
###############################################################################

###############################################################################
# STEP 0: SAFE LOAD .ENV (IF AVAILABLE)
###############################################################################
echo "[1/9] Loading environment variables from .env (if exists)..."
if [ -f ".env" ]; then
  while IFS= read -r line; do
    # Skip empty/comment lines
    if [[ -z "$line" || "$line" =~ ^# ]]; then
      continue
    fi
    # Only export lines that match KEY=VALUE
    if [[ "$line" =~ ^[A-Za-z0-9_]+=.* ]]; then
      export "$line"
    fi
  done < .env
  echo "[INFO] .env file loaded (comments & blank lines ignored)."
else
  echo "[WARNING] .env not found. Please ensure environment variables (like MONGO_DETAILS, OPENAI_API_KEY) are set."
fi

###############################################################################
# STEP 1: (OPTIONAL) SYSTEM UPDATES (UBUNTU/DEBIAN)
###############################################################################
echo "[2/9] Checking system updates..."
sudo apt-get update -y
sudo apt-get upgrade -y
# Optional:
# sudo apt-get dist-upgrade -y
# sudo apt-get autoremove -y
echo "[INFO] System packages updated (basic)."

###############################################################################
# STEP 2: FORCE DOCKER-COMPOSE (DASH) v2
###############################################################################
echo "[3/9] Forcing docker-compose usage..."
composeBinary="docker-compose"

# Ensure docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
  echo "[ERROR] 'docker-compose' command not found. Install/fix the standalone Compose v2 binary."
  exit 1
else
  cVersion="$(docker-compose version 2>&1 || true)"
  if ! echo "$cVersion" | grep -Eq 'version.*(v)?2'; then
    echo "[WARNING] 'docker-compose' found but might be v1 or limited features."
  else
    echo "[INFO] Found Docker Compose v2 via 'docker-compose'."
  fi
fi

# For subcommands
declare -a cCmd=("$composeBinary")

###############################################################################
# STEP 3: PULL, BUILD, AND RUN CONTAINERS (NO-CACHE)
###############################################################################
echo "[4/9] Pulling images (optional) and building no-cache..."
echo "[INFO] Pulling base images (optional)."
"${cCmd[@]}" pull || true

echo "[INFO] Building containers with no cache..."
"${cCmd[@]}" build --no-cache

echo "[INFO] Starting containers in detached mode..."
"${cCmd[@]}" up -d

###############################################################################
# STEP 4: ADVANCED LOG CAPTURE BEFORE HEALTH CHECK
###############################################################################
echo "[5/9] Capturing startup logs (tail=100) for possible errors..."
"${cCmd[@]}" logs --tail=100 > logs_startup.txt || true
echo "[INFO] Logs appended to logs_startup.txt. Searching for errors/warnings..."
grep -iE '(error|exception|warning|traceback)' logs_startup.txt || true

###############################################################################
# STEP 5: WAIT FOR HEALTHY CONTAINERS (WITH PARTIAL PROGRESS)
###############################################################################
TIMEOUT=60
echo "[6/9] Waiting up to $TIMEOUT seconds for containers to become healthy..."

# Adjust these to match your docker-compose.yml services
REQUIRED_SERVICES=("solana_agents" "ragchain_service" "quant_service")
START_TIME=$(date +%s)

while true; do
  ALL_HEALTHY=true
  UNHEALTHY_LIST=()

  for svc in "${REQUIRED_SERVICES[@]}"; do
    SERVICE_ID=$("${cCmd[@]}" ps -q "$svc" || true)
    if [ -z "$SERVICE_ID" ]; then
      ALL_HEALTHY=false
      UNHEALTHY_LIST+=("${svc}(NoID)")
      continue
    fi
    HEALTH_STATE=$(docker inspect -f '{{.State.Health.Status}}' "$SERVICE_ID" 2>/dev/null || true)
    if [ "$HEALTH_STATE" != "healthy" ]; then
      ALL_HEALTHY=false
      UNHEALTHY_LIST+=("${svc}(${HEALTH_STATE})")
    fi
  done

  if [ "$ALL_HEALTHY" = true ]; then
    echo "[INFO] All required services are healthy."
    break
  fi

  ELAPSED=$(( $(date +%s) - START_TIME ))
  if [ "$ELAPSED" -gt "$TIMEOUT" ]; then
    echo "[ERROR] Timeout ($TIMEOUT s). Not healthy: ${UNHEALTHY_LIST[*]}"
    "${cCmd[@]}" ps
    exit 1
  fi

  echo "[INFO] Not all containers healthy yet: ${UNHEALTHY_LIST[*]}"
  echo "[INFO] Will retry in 5s..."
  sleep 5
done

###############################################################################
# STEP 6: SMART MEMORY & ORACLE PLACEHOLDERS
###############################################################################
echo "[7/9] Brain-Inspired 'Smart Memory' expansions for ephemeral logic, Oracle data..."
cat <<SMART
1) Ephemeral Memory (Chain-of-Thought):
   - Keep short-lived chain-of-thought or reasoning logs in a small DB or memory store,
     then discard after the task completes.

2) Oracle Integration:
   - If you have external Oracle feeds (e.g., interest rates, price data from external
     markets), unify them with on-chain data from solana_agents. 
   - Provide ephemeral context to ragchain_service or quant_service for advanced analysis.

3) Hierarchical Modules:
   - Break quant_service into multiple layers (data prep, AI modeling, trading decisions).
   - Each layer can log ephemeral reasoning or chain-of-thought for debugging or dynamic learning.
SMART

###############################################################################
# STEP 7: OPENAI & ADVANCED AI
###############################################################################
echo "[8/9] (Optional) Integrate LLM logic or ephemeral chain-of-thought with OPENAI_API_KEY."
cat <<AI
- If you have an OPENAI_API_KEY in .env, you could run a small script that
  sends ephemeral logs to GPT for chain-of-thought debugging or "explain 
  your reasoning" steps in real-time. 
- Combine ephemeral memory with the advanced ephemeral logs to create a
  short-term memory that AI can reference or refine.
AI

###############################################################################
# STEP 8: DONE
###############################################################################
echo "[9/9] update_master_smart.sh finished successfully!"
echo "All containers should be up (or soon will be). Logs in logs_startup.txt."
echo "For real-time logs: 'docker-compose logs -f <service>'."
