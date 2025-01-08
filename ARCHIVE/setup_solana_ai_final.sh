#!/usr/bin/env bash
set -e

###############################################################################
# setup_solana_ai_final.sh
#
# Creates a multi-service Docker-based architecture:
#  - docker-compose.yml with: solana_agents (Node.js), ragchain_service (Python),
#    quant_service (Python), local_mongo (MongoDB).
#  - Dockerfiles + minimal code for ephemeral chain-of-thought memory in Mongo.
#  - final_extreme_monitor_v4.sh for building, logs analysis, CPU/mem usage, etc.
#
# Usage:
#   chmod +x setup_solana_ai_final.sh
#   ./setup_solana_ai_final.sh
#   docker-compose build
#   docker-compose up -d
#   ./final_extreme_monitor_v4.sh
###############################################################################

echo "[INFO] Generating docker-compose.yml..."
cat << 'EOF' > docker-compose.yml
version: '3.8'
services:
  solana_agents:
    build: ./solana_agents
    container_name: solana_agents
    ports:
      - "4000:4000"
    environment:
      PORT: 4000
      SOLANA_RPC_URL: ${SOLANA_RPC_URL}
      SOLANA_PRIVATE_KEY: ${SOLANA_PRIVATE_KEY}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      GEMINI_API_KEY: ${GEMINI_API_KEY}
      TAVILY_API_KEY: ${TAVILY_API_KEY}
      RAGCHAIN_URL: http://ragchain_service:5000
      QUANT_URL: http://quant_service:7000
    depends_on:
      - ragchain_service
      - quant_service
      - local_mongo
    networks:
      - app-net

  ragchain_service:
    build: ./ragchain_service
    container_name: ragchain_service
    ports:
      - "5000:5000"
    environment:
      MONGO_DETAILS: ${MONGO_DETAILS}
    depends_on:
      - local_mongo
    networks:
      - app-net

  quant_service:
    build: ./quant_service
    container_name: quant_service
    ports:
      - "7000:7000"
    environment:
      MONGO_DETAILS: ${MONGO_DETAILS}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      GEMINI_API_KEY: ${GEMINI_API_KEY}
      TAVILY_API_KEY: ${TAVILY_API_KEY}
      SOLANA_RPC_URL: ${SOLANA_RPC_URL}
    depends_on:
      - local_mongo
    networks:
      - app-net

  local_mongo:
    image: mongo:6.0
    container_name: local_mongo
    command: ["mongod", "--bind_ip", "0.0.0.0"]
    ports:
      - "27017:27017"
    networks:
      - app-net
    healthcheck:
      test: ["CMD", "mongo", "--eval", "db.runCommand({ ping: 1 })", "--quiet"]
      interval: 10s
      timeout: 5s
      retries: 5
    volumes:
      - mongo_data:/data/db

networks:
  app-net:

volumes:
  mongo_data:
EOF

###############################################################################
# solana_agents
###############################################################################
echo "[INFO] Creating Dockerfile for solana_agents..."
mkdir -p solana_agents
cat << 'EOF' > solana_agents/Dockerfile
FROM node:20-alpine

WORKDIR /app
RUN apk update && apk add --no-cache git bash grep sed curl

COPY package.json ./ 
RUN npm install

COPY app /app

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
  CMD curl -f http://localhost:4000/health || exit 1

CMD ["node", "index.js"]
EOF

echo "[INFO] Creating solana_agents code..."
mkdir -p solana_agents/app
cat << 'EOF' > solana_agents/app/package.json
{
  "name": "qmcs-solana_agents",
  "version": "1.0.0",
  "description": "Solana Agents orchestrator with ephemeral memory usage, multi-LLM references",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "axios": "^1.4.0",
    "cron": "^2.2.0",
    "express": "^4.18.2",
    "uuid": "^9.0.0",
    "dotenv": "^16.3.1"
  }
}
EOF

cat << 'EOF' > solana_agents/app/index.js
require('dotenv').config();
const express = require('express');
const axios = require('axios');
const cron = require('cron');  // from "npm install cron"
const { CronJob } = cron;
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(express.json());

const logger = {
  info: (...args) => console.log(new Date().toISOString(), "[INFO]", ...args),
  warn: (...args) => console.warn(new Date().toISOString(), "[WARN]", ...args),
  error: (...args) => console.error(new Date().toISOString(), "[ERROR]", ...args),
};

const PORT = process.env.PORT || 4000;
const RAGCHAIN_URL = process.env.RAGCHAIN_URL;
const QUANT_URL = process.env.QUANT_URL;

logger.info("solana_agents config:", { PORT, RAGCHAIN_URL, QUANT_URL });

app.get('/health', (req, res) => {
  return res.status(200).send({message: "solana_agents healthy"});
});

// ephemeral chain-of-thought store
async function storeEphemeralThought(thought) {
  if(!RAGCHAIN_URL) {
    logger.warn("[solana_agents] RAGCHAIN_URL not set, can't store ephemeral thought.");
    return;
  }
  try {
    await axios.post(`${RAGCHAIN_URL}/store_thought/`, { thought });
    logger.info("[solana_agents] ephemeral thought stored:", thought);
  } catch(e) {
    logger.error("[solana_agents] Failed storeEphemeralThought:", e.message);
  }
}

// Setup CRON to store daily ephemeral thought
const dailyJob = new CronJob('0 0 * * *', async () => {
  logger.info("[solana_agents] daily CRON => storing ephemeral thought");
  await storeEphemeralThought("Daily tick from solana_agents: " + new Date().toISOString());
});
dailyJob.start();

// Example endpoint: fetch ephemeral chain-of-thought from ragchain
app.get('/ephemeral-ideas', async (req, res) => {
  if(!RAGCHAIN_URL) return res.status(400).send({ error: "No RAGCHAIN_URL" });
  try {
    const { data } = await axios.get(`${RAGCHAIN_URL}/ephemeral_ideas`);
    return res.status(200).send({ data });
  } catch(e) {
    logger.error("Failed to fetch ephemeral ideas:", e.message);
    return res.status(500).send({ error: e.message });
  }
});

app.listen(PORT, () => {
  logger.info(`solana_agents listening on port ${PORT}`);
});
EOF

###############################################################################
# ragchain_service
###############################################################################
echo "[INFO] Creating Dockerfile for ragchain_service..."
mkdir -p ragchain_service
cat << 'EOF' > ragchain_service/Dockerfile
FROM python:3.11-slim-buster

WORKDIR /app
RUN pip install --no-cache-dir fastapi uvicorn pydantic python-dotenv requests httpx pymongo

COPY app /app

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
  CMD curl -f http://localhost:5000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5000"]
EOF

echo "[INFO] Creating ragchain_service code..."
mkdir -p ragchain_service/app
cat << 'EOF' > ragchain_service/app/main.py
import os
import logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("ragchain_service")
logging.basicConfig(level=logging.INFO)

MONGO_DETAILS = os.getenv("MONGO_DETAILS", "")

app = FastAPI()

try:
    if not MONGO_DETAILS:
        logger.warning("MONGO_DETAILS not provided; ephemeral chain-of-thought won't persist.")
        chain_collection = None
    else:
        client = MongoClient(MONGO_DETAILS)
        ephemeral_db = client["ephemeral_memory"]
        chain_collection = ephemeral_db["chain_of_thought"]
except Exception as e:
    logger.error(f"[ragchain_service] Could not connect to Mongo: {e}")
    chain_collection = None

class ThoughtIn(BaseModel):
    thought: str

class ThoughtOut(BaseModel):
    _id: str
    thought: str

@app.get("/health")
def health():
    return {"message": "ragchain_service healthy"}

@app.post("/store_thought/")
def store_thought(thought_in: ThoughtIn):
    if not chain_collection:
        raise HTTPException(status_code=500, detail="No ephemeral chain_collection found.")
    doc = { "thought": thought_in.thought, "timestamp": str(os.times()) }
    result = chain_collection.insert_one(doc)
    return {"inserted_id": str(result.inserted_id)}

@app.get("/ephemeral_ideas", response_model=List[ThoughtOut])
def ephemeral_ideas():
    if not chain_collection:
        raise HTTPException(status_code=500, detail="No ephemeral chain_collection found.")
    docs = chain_collection.find().sort("_id",-1).limit(20)
    out = []
    for d in docs:
        out.append({"_id": str(d["_id"]), "thought": d["thought"]})
    return out
EOF

###############################################################################
# quant_service
###############################################################################
echo "[INFO] Creating Dockerfile for quant_service..."
mkdir -p quant_service
cat << 'EOF' > quant_service/Dockerfile
FROM python:3.11-slim-buster

WORKDIR /app
RUN pip install --no-cache-dir fastapi uvicorn pydantic python-dotenv requests pandas numpy pymongo

COPY app /app

EXPOSE 7000

HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
  CMD curl -f http://localhost:7000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7000"]
EOF

echo "[INFO] Creating quant_service code..."
mkdir -p quant_service/app
cat << 'EOF' > quant_service/app/main.py
import os
import logging
from fastapi import FastAPI
from dotenv import load_dotenv
from typing import List
from pymongo import MongoClient
import pandas as pd
import numpy as np
from datetime import datetime

load_dotenv()

logger = logging.getLogger("quant_service")
logging.basicConfig(level=logging.INFO)

app = FastAPI()

MONGO_DETAILS = os.getenv("MONGO_DETAILS","")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY","")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY","")
TAVILY_API_KEY = os.getenv("TAVILY_API_KEY","")
SOLANA_RPC_URL = os.getenv("SOLANA_RPC_URL","")

mongo_client = None
chain_collection = None

@app.on_event("startup")
def startup_db_client():
    global mongo_client, chain_collection
    if MONGO_DETAILS:
        try:
            mongo_client = MongoClient(MONGO_DETAILS)
            ephemeral_db = mongo_client["ephemeral_memory"]
            chain_collection = ephemeral_db["chain_of_thought"]
            logger.info("[quant_service] ephemeral chain-of-thought connected.")
        except Exception as e:
            logger.error(f"[quant_service] Could not connect ephemeral memory: {e}")
            chain_collection = None
    else:
        logger.warning("[quant_service] No MONGO_DETAILS => ephemeral usage won't persist.")
        chain_collection = None

@app.on_event("shutdown")
def shutdown_db_client():
    if mongo_client:
        mongo_client.close()

@app.get("/health")
def health():
    return {"message": "quant_service healthy"}

@app.get("/track-top-wallets")
def track_top_wallets():
    """
    Example endpoint: pretend we track top 1000 Solana wallets. We'll store ephemeral note.
    """
    if chain_collection:
        chain_collection.insert_one({"thought":"Tracking top 1000 solana wallets", "date":str(datetime.utcnow())})
    return {"status":"ok", "desc":"Pretend we do advanced logic here."}

@app.get("/example-strategy")
def example_strategy():
    """
    Demonstration endpoint for short/long strategy with multi-LLM placeholders.
    """
    # If we want ephemeral memory logs:
    if chain_collection:
        chain_collection.insert_one({"thought":"Example strategy triggered", "time":str(datetime.utcnow())})
    # Multi-LLM usage placeholders if complexity is high => GPT-4 or Gemini / TAVILY
    # We'll just return a placeholder
    return {
      "strategy": "BUY if SOL < 1.0, else HOLD",
      "openai_api_key": bool(OPENAI_API_KEY),
      "gemini_api_key": bool(GEMINI_API_KEY),
      "tavily_api_key": bool(TAVILY_API_KEY),
      "solana_rpc_url": SOLANA_RPC_URL
    }
EOF

###############################################################################
# final_extreme_monitor_v4.sh
###############################################################################
echo "[INFO] Adding final_extreme_monitor_v4.sh..."
cat << 'EOF' > final_extreme_monitor_v4.sh
#!/usr/bin/env bash
set -e

# final_extreme_monitor_v4.sh
# Build images, remove old containers, logs analysis, CPU/mem usage, ephemeral memory, etc.

trap ctrl_c INT
function ctrl_c() {
  echo ""
  echo "[WARN] Caught Ctrl+C. Aborting final_extreme_monitor_v4.sh."
  exit 1
}

MATRIX_GREEN='\033[38;5;82m'
MATRIX_DARKGREEN='\033[38;5;22m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

LOG_FILE="vots_mistakes.log"

info()  { echo -e "${MATRIX_GREEN}[INFO] $*${RESET}"; }
note()  { echo -e "${MATRIX_DARKGREEN}[NOTE] $*${RESET}"; }
warn()  { echo -e "${YELLOW}[WARN] $*${RESET}"; echo "$(date) [WARN] $*" >> "$LOG_FILE"; }
err()   { echo -e "${RED}[ERROR] $*${RESET}"; echo "$(date) [ERROR] $*" >> "$LOG_FILE"; exit 1; }

echo -e "${MATRIX_GREEN} __      ___   ___ _____ "
echo -e " \\ \\    / / | | |_ _|_   _|"
echo -e "  \\ \\/\\/ /| | | || |  | |  "
echo -e "   \\_/\\_/ | |_| || |  | |  "
echo -e "         |_____|___| |_|  ${RESET}"
echo -e "${MATRIX_DARKGREEN}--- final_extreme_monitor_v4.sh (VOTS) ---${RESET}"

info "Removing old containers for: solana_agents ragchain_service quant_service local_mongo..."
docker ps -a | grep -E 'solana_agents|ragchain_service|quant_service|local_mongo' | awk '{print $1}' | xargs -r docker rm -f || true

info "Building Docker images..."
docker-compose build

info "Starting containers in detached mode..."
docker-compose up -d

MAX_WAIT=90
start_time=$(date +%s)
services=(solana_agents ragchain_service quant_service local_mongo)

info "Waiting up to $MAX_WAIT seconds for Docker health..."

while true; do
  all_healthy=true
  for svc in "${services[@]}"; do
    cid=$(docker-compose ps -q "$svc" 2>/dev/null || true)
    if [ -z "$cid" ]; then
      warn "No container found for $svc"
      all_healthy=false
      continue
    fi
    # check health if the container sets it
    status=$(docker inspect --format='{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "missing")
    if [ "$svc" = "local_mongo" ]; then
      # official mongo might be healthy or "starting"; skip strict check
      if [ "$status" = "starting" ] || [ "$status" = "healthy" ]; then
        # okay
        :
      else
        # might be missing or 'unhealthy'
        warn "mongo => status: $status"
      fi
    else
      if [ "$status" != "healthy" ]; then
        all_healthy=false
        break
      fi
    fi
  done
  if $all_healthy; then
    info "All requested Docker services are healthy or started!"
    break
  fi
  elapsed=$(( $(date +%s) - start_time ))
  if [ $elapsed -ge $MAX_WAIT ]; then
    warn "Not all containers became healthy within $MAX_WAIT seconds."
    break
  fi
  sleep 5
done

declare -A PORTS=(
  ["solana_agents"]="4000"
  ["ragchain_service"]="5000"
  ["quant_service"]="7000"
  ["local_mongo"]="27017"
)

note "Performing container port checks (nc -z localhost)..."
for svc in "${!PORTS[@]}"; do
  port="${PORTS[$svc]}"
  if nc -z localhost "$port"; then
    info "$svc => host port $port is open"
  else
    warn "$svc => host port $port not open"
  fi
done

note "Checking /health endpoints (skip local_mongo) on localhost..."
for svc in solana_agents ragchain_service quant_service; do
  port="${PORTS[$svc]}"
  if curl -sf "http://localhost:$port/health" >/dev/null; then
    info "$svc => /health responded OK on localhost:$port"
  else
    warn "$svc => /health check failed on localhost:$port"
  fi
done

info "Analyzing last 100 lines of logs for keywords: error exception traceback fail"
KEYWORDS="error|exception|traceback|fail"
for svc in "${services[@]}"; do
  cid=$(docker-compose ps -q "$svc" || true)
  if [ -z "$cid" ]; then
    warn "No container for $svc, skipping logs check."
    continue
  fi
  note "===== $svc logs (tail 100) ====="
  logs=$(docker logs --tail=100 "$cid" 2>&1 || true)
  echo "$logs"
  echo ""
  matches=$(echo "$logs" | grep -iE "$KEYWORDS" | wc -l)
  if [ "$matches" -gt 0 ]; then
    warn "$svc => found $matches matches for $KEYWORDS"
  else
    info "$svc => no $KEYWORDS found"
  fi
done

info "Checking container CPU/Memory usage (docker stats --no-stream)..."
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

info "System resource usage..."

LOAD_AVG=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
info "CPU Load (1/5/15): $LOAD_AVG"

# parse total + used
mem_line=$(free -m | awk '/Mem:/ {print $2" "$3}')
TOTAL_MEM=$(echo "$mem_line" | awk '{print $1}')
USED_MEM=$(echo "$mem_line" | awk '{print $2}')

if [ -z "$TOTAL_MEM" ] || [ "$TOTAL_MEM" -eq 0 ]; then
  warn "Memory total is 0 or missing, skipping usage calc."
else
  pct=$(awk -v used="$USED_MEM" -v total="$TOTAL_MEM" 'BEGIN { if(total>0){printf "%.1f", used*100/total}else{printf "0"} }')
  info "Memory Usage: ${USED_MEM}MB used / ${TOTAL_MEM}MB total (${pct}%)"
fi

swap_line=$(free -m | awk '/Swap:/ {print $2" "$3}')
SWAP_TOTAL=$(echo "$swap_line" | awk '{print $1}')
SWAP_USED=$(echo "$swap_line" | awk '{print $2}')

if [ -z "$SWAP_TOTAL" ] || [ "$SWAP_TOTAL" -eq 0 ]; then
  info "Swap Usage: 0MB used / 0MB total (0%)"
else
  spct=$(awk -v used="$SWAP_USED" -v total="$SWAP_TOTAL" 'BEGIN { if(total>0){printf "%.1f", used*100/total}else{printf "0"} }')
  info "Swap Usage: ${SWAP_USED}MB used / ${SWAP_TOTAL}MB total (${spct}%)"
fi

disk_usage=$(df -h / | awk 'NR==2{print $5 " used on /"}')
info "Disk Usage on /: $disk_usage"

if [ -z "$OPENAI_API_KEY" ]; then
  warn "OPENAI_API_KEY not set, skipping AI summary placeholder."
else
  note "Minimal AI summary placeholder => customize logic if needed."
  echo "--- AI Summary End ---"
fi

note "final_extreme_monitor_v4.sh complete! Check vots_mistakes.log if needed."
EOF

echo ""
echo "[INFO] Done generating code. Next steps:"
echo "1) docker-compose build"
echo "2) docker-compose up -d"
echo "3) ./final_extreme_monitor_v4.sh"
