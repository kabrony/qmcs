#!/usr/bin/env bash
set -e

###############################################################################
# UPDATE + "BRAIN MEMORY" MASTER SCRIPT (FORCING `docker-compose`)
# Purpose:
#   1) Load .env safely (OpenAI keys, MONGO_DETAILS, SOLANA_PRIVATE_KEY, etc.).
#   2) Perform apt-based system updates (Ubuntu/Debian).
#   3) Force the use of `docker-compose` (dash), ignoring plugin subcommand.
#   4) Rebuild containers (no-cache), optionally pulling latest images.
#   5) Wait for containers to be healthy (Docker health checks).
#   6) Placeholders for advanced "Brain Memory Architecture" (semantic links, 
#      hierarchical layering, ephemeral memory, dynamic adaptation).
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
    # Only export lines that have KEY=VALUE
    if [[ "$line" =~ ^[A-Za-z0-9_]+=.* ]]; then
      export "$line"
    fi
  done < .env
  echo "[INFO] .env file loaded (comments & blank lines ignored)."
else
  echo "[WARNING] .env file not found. Ensure environment vars are set or create .env."
fi

###############################################################################
# STEP 1: SYSTEM UPDATES (UBUNTU/DEBIAN)
###############################################################################
echo "[2/9] Checking system updates..."
sudo apt-get update -y
sudo apt-get upgrade -y
# Optionally:
# sudo apt-get dist-upgrade -y
# sudo apt-get autoremove -y
echo "[INFO] System packages updated."

###############################################################################
# STEP 2: FORCE `docker-compose` (dash)
###############################################################################
echo "[3/9] Forcing docker-compose (dash) usage..."
composeBinary="docker-compose"

# Confirm it's actually installed & v2
if ! command -v docker-compose &> /dev/null; then
  echo "[ERROR] 'docker-compose' not found. Install or fix the standalone Compose v2 binary."
  exit 1
else
  # Optionally check version includes 'v2'
  cVersion="$(docker-compose version 2>&1 || true)"
  if ! echo "$cVersion" | grep -Eq 'version.*(v)?2'; then
    echo "[WARNING] 'docker-compose' found but might be v1 or limited features."
  else
    echo "[INFO] Found Docker Compose v2 standalone via 'docker-compose'."
  fi
fi

###############################################################################
# STEP 3: PULL & BUILD CONTAINERS
###############################################################################
echo "[4/9] Pulling images (optional) and building no-cache..."

# Put command in an array for subcommand usage
declare -a cCmd=("$composeBinary")

# Pull images (optional)
echo "[INFO] Pulling base images (optional)."
"${cCmd[@]}" pull || true

# Build with no cache
echo "[INFO] Building containers with no cache..."
"${cCmd[@]}" build --no-cache

# Start containers in detached mode
echo "[INFO] Starting containers..."
"${cCmd[@]}" up -d

###############################################################################
# STEP 4: WAIT FOR HEALTHY CONTAINERS
###############################################################################
TIMEOUT=60
echo "[5/9] Waiting up to $TIMEOUT seconds for containers to become healthy..."

REQUIRED_SERVICES=("solana_agents" "ragchain_service" "quant_service")
START_TIME=$(date +%s)

while true; do
  ALL_HEALTHY=true
  for svc in "${REQUIRED_SERVICES[@]}"; do
    SERVICE_ID=$("${cCmd[@]}" ps -q "$svc" || true)
    if [ -z "$SERVICE_ID" ]; then
      ALL_HEALTHY=false
      break
    fi
    HEALTH_STATE=$(docker inspect -f '{{.State.Health.Status}}' "$SERVICE_ID" 2>/dev/null || true)
    if [ "$HEALTH_STATE" != "healthy" ]; then
      ALL_HEALTHY=false
      break
    fi
  done

  if [ "$ALL_HEALTHY" = true ]; then
    echo "[INFO] All required services are healthy."
    break
  fi

  ELAPSED=$(( $(date +%s) - START_TIME ))
  if [ "$ELAPSED" -gt "$TIMEOUT" ]; then
    echo "[ERROR] Timeout ($TIMEOUT s). Some services never reported healthy."
    "${cCmd[@]}" ps
    exit 1
  fi

  echo "[INFO] Not all containers healthy yet, retrying in 5s..."
  sleep 5
done

###############################################################################
# STEP 5: BRAIN MEMORY ARCHITECTURE PLACEHOLDERS
###############################################################################
echo "[6/9] Brain-Inspired Memory Enhancements (Conceptual Implementation):"
cat <<BRAIN
1) Enhanced Info Integration & Association:
   - Use a knowledge graph or vector DB that unites Solana data, RAG outputs, 
     and quant results for deeper semantic links.

2) Context-Dependent Retrieval:
   - Store session-based or episodic context in ragchain_service or a memory 
     store (e.g., user states, conversation history) for relevant retrieval.

3) Hierarchical Processing:
   - Break quant_service tasks into layers (raw data ingestion, feature eng,
     advanced AI modeling, final strategy). Log chain-of-thought for interpretability.

4) Dynamic Adaptation & Learning:
   - Use RL loops or continuous retraining to adapt to new data. 
   - Provide feedback loops to refine RAG retrieval or quant strategies.
BRAIN

###############################################################################
# STEP 6: OPENAI / SMART MEMORY LOGIC (OPTIONAL)
###############################################################################
echo "[7/9] (Optional) Integrate advanced LLM debugging or ephemeral memory logic."
cat <<OPENAI
- If you have OPENAI_API_KEY, orchestrate real-time queries to GPT models, 
  store chain-of-thought in ephemeral memory, or unify it with on-chain data 
  in solana_agents for deeper context. 
- For example, run a script that queries OpenAI to interpret unusual market events.
OPENAI

###############################################################################
# STEP 7: QUANT / SOLANA REINFORCEMENT
###############################################################################
echo "[8/9] (Optional) Re-check quant_service for RL or advanced data adaptation."
cat <<QUANT
- If your quant_service has RL, incorporate real-time performance as a feedback 
  signal. 
- Add ephemeral or short-term memory (e.g., a scratch DB or in-memory store) 
  that influences immediate trades, while final data is logged for long-term strategy updates.
QUANT

###############################################################################
# STEP 8: DONE
###############################################################################
echo "[9/9] update_master_brain.sh finished successfully!"
echo "All containers should be up and healthy. Check logs with '${composeBinary} logs <service>'."
