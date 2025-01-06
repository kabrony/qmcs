#!/usr/bin/env bash
set -e

###############################################################################
# setup_final_architecture.sh
#
# Creates a multi-service Docker-based architecture that uses:
#  - solana_agents (Node.js) => orchestrates tasks w/ Solana, LLM env vars
#  - ragchain_service (Python) => ephemeral chain-of-thought in MongoDB
#  - quant_service (Python) => optional quant/circuits expansions
#  - A utils folder (Python) for shared logic
#  - final_extreme_monitor_v4.sh for building & monitoring
#
# Usage:
#   chmod +x setup_final_architecture.sh
#   ./setup_final_architecture.sh
# Then:
#   docker compose build
#   docker compose up -d
#   ./final_extreme_monitor_v4.sh
###############################################################################

echo "[INFO] Creating directories..."

mkdir -p solana_agents
mkdir -p solana_agents/app
mkdir -p ragchain_service/app
mkdir -p quant_service/app
mkdir -p utils/app

###############################################################################
# 1) Dockerfiles
###############################################################################
echo "[INFO] Creating Dockerfile for solana_agents..."
cat << 'EOF' > solana_agents/Dockerfile
FROM node:20-alpine

WORKDIR /app

RUN apk update && apk add --no-cache git bash grep sed curl

COPY package.json ./
RUN npm install

COPY . .

EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
  CMD curl -f http://localhost:4000/health || exit 1

CMD ["node", "index.js"]
EOF

echo "[INFO] Creating Dockerfile for ragchain_service (Python, uses MongoDB)..."
cat << 'EOF' > ragchain_service/Dockerfile
FROM python:3.11-slim-buster

WORKDIR /app

# Ephemeral chain-of-thought memory w/ pymongo
RUN pip install --no-cache-dir fastapi uvicorn pydantic python-dotenv requests httpx pymongo

COPY ./app /app
COPY ./../utils /utils

ENV PYTHONPATH="/:/utils"

EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
  CMD curl -f http://localhost:5000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5000"]
EOF

echo "[INFO] Creating Dockerfile for quant_service (Python, optional expansions)..."
cat << 'EOF' > quant_service/Dockerfile
FROM python:3.11-slim-buster

WORKDIR /app

RUN pip install --no-cache-dir fastapi uvicorn pydantic python-dotenv requests

COPY ./app /app
COPY ./../utils /utils

ENV PYTHONPATH="/:/utils"

EXPOSE 7000
HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
  CMD curl -f http://localhost:7000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7000"]
EOF

###############################################################################
# 2) Docker Compose
###############################################################################
echo "[INFO] Creating docker-compose.yml..."
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
      # Common environment usage:
      SOLANA_RPC_URL: ${SOLANA_RPC_URL}
      SOLANA_PRIVATE_KEY: ${SOLANA_PRIVATE_KEY}
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      GEMINI_API_KEY: ${GEMINI_API_KEY}
      TAVILY_API_KEY: ${TAVILY_API_KEY}
      DEEPSEEK_API_KEY: ${DEEPSEEK_API_KEY}
      # If referencing other services:
      RAGCHAIN_SERVICE_URL: http://ragchain_service:5000
      QUANT_SERVICE_URL: http://quant_service:7000
    depends_on:
      - ragchain_service
      - quant_service
    networks:
      - app-network

  ragchain_service:
    build: ./ragchain_service
    container_name: ragchain_service
    ports:
      - "5000:5000"
    environment:
      MONGO_DETAILS: ${MONGO_DETAILS}   # e.g. your DigitalOcean cluster
      OPENAI_API_KEY: ${OPENAI_API_KEY} # if needed for advanced logic
    networks:
      - app-network

  quant_service:
    build: ./quant_service
    container_name: quant_service
    ports:
      - "7000:7000"
    environment:
      OPENAI_API_KEY: ${OPENAI_API_KEY}
    networks:
      - app-network

networks:
  app-network:
EOF

###############################################################################
# 3) solana_agents
###############################################################################
echo "[INFO] Creating solana_agents code..."

# package.json
cat << 'EOF' > solana_agents/package.json
{
  "name": "qmcs-solana_agents",
  "version": "1.0.0",
  "description": "Solana Agents orchestrator with environment usage",
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

# index.js
cat << 'EOF' > solana_agents/index.js
require('dotenv').config();
const axios = require('axios');
const cron = require('node-cron');
const express = require('express');
const app = express();
app.use(express.json());

const { v4: uuidv4 } = require('uuid');

const logger = {
  info: (...args) => console.log(new Date().toISOString(), "[INFO]", ...args),
  error: (...args) => console.error(new Date().toISOString(), "[ERROR]", ...args),
  warn: (...args) => console.warn(new Date().toISOString(), "[WARN]", ...args),
};

const PORT = process.env.PORT || 4000;
const RAGCHAIN_SERVICE_URL = process.env.RAGCHAIN_SERVICE_URL; 
const QUANT_SERVICE_URL = process.env.QUANT_SERVICE_URL;
const SOLANA_RPC_URL = process.env.SOLANA_RPC_URL;
const SOLANA_PRIVATE_KEY = process.env.SOLANA_PRIVATE_KEY;

logger.info("Starting solana_agents with config:", {
  PORT, RAGCHAIN_SERVICE_URL, QUANT_SERVICE_URL, SOLANA_RPC_URL
});

app.get('/health', (req, res) => {
  res.status(200).send({message: "Healthy"});
});

//////////////////////////////////////////////////////////
// Example: call ragchain to store ephemeral chain-of-thought
//////////////////////////////////////////////////////////
async function storeChainOfThought(thought) {
  if(!RAGCHAIN_SERVICE_URL) {
    logger.warn("No RAGCHAIN_SERVICE_URL set");
    return;
  }
  try {
    const resp = await axios.post(`${RAGCHAIN_SERVICE_URL}/store_thought/`, { thought });
    return resp.data;
  } catch(e) {
    logger.error("Failed to store ephemeral chain-of-thought:", e.message);
  }
}

//////////////////////////////////////////////////////////
// Example CRON: daily tasks at midnight
//////////////////////////////////////////////////////////
cron.schedule('0 0 * * *', async () => {
  logger.info('Running daily tasks...');
  await storeChainOfThought(`Daily tick: ${new Date().toISOString()}`);
});

//////////////////////////////////////////////////////////
// Expose simple endpoints
//////////////////////////////////////////////////////////
app.get('/get-ephemeral-ideas', async (req, res) => {
  if(!RAGCHAIN_SERVICE_URL) {
    return res.status(400).send({ message: "No RAGCHAIN_SERVICE_URL" });
  }
  try {
    const resp = await axios.get(`${RAGCHAIN_SERVICE_URL}/ephemeral_ideas`);
    return res.status(200).send({ data: resp.data });
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
# 4) ragchain_service (Python) - ephemeral memory in Mongo
###############################################################################
echo "[INFO] Creating ragchain_service code..."

cat << 'EOF' > ragchain_service/app/main.py
import os
import logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()

MONGO_DETAILS = os.getenv("MONGO_DETAILS", "")
if not MONGO_DETAILS:
    print("[ERROR] MONGO_DETAILS not set in environment!")
    # We can still proceed, but it won't connect properly

logger = logging.getLogger("ragchain_service")
logger.setLevel(logging.INFO)

app = FastAPI()

# Connect to Mongo
try:
    client = MongoClient(MONGO_DETAILS)
    ephemeral_db = client["ephemeral_memory"]
    chain_collection = ephemeral_db["chain_of_thought"]
except Exception as e:
    logger.error(f"Could not connect to Mongo: {e}")
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
        raise HTTPException(status_code=500, detail="Mongo not connected.")
    record = {
      "thought": thought_in.thought,
      "timestamp": str(os.times())
    }
    result = chain_collection.insert_one(record)
    return {"inserted_id": str(result.inserted_id)}

@app.get("/ephemeral_ideas", response_model=List[ThoughtOut])
def ephemeral_ideas():
    if not chain_collection:
        raise HTTPException(status_code=500, detail="Mongo not connected.")
    docs = chain_collection.find().sort("_id", -1).limit(20)
    out = []
    for d in docs:
        out.append({"_id": str(d["_id"]), "thought": d["thought"]})
    return out
EOF

###############################################################################
# 5) quant_service (Python) - optional expansions
###############################################################################
echo "[INFO] Creating quant_service code..."

cat << 'EOF' > quant_service/app/main.py
import os
import logging
from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger("quant_service")
logger.setLevel(logging.INFO)

app = FastAPI()

@app.get("/health")
def health():
    return {"message": "quant_service healthy"}

# Could implement circuit or advanced quant logic here
@app.get("/example-circuits")
def example_circuits():
    return {"circuits": ["circuitA", "circuitB", "circuitC"]}
EOF

###############################################################################
# 6) utils - minimal, shared logic
###############################################################################
echo "[INFO] Creating utils code..."

cat << 'EOF' > utils/app/__init__.py
# can be empty or place shared logic
EOF

cat << 'EOF' > utils/app/utils.py
import logging

def example_shared_function():
    return "Hello from utils"
EOF

###############################################################################
# 7) final_extreme_monitor_v4.sh
###############################################################################
echo "[INFO] Creating final_extreme_monitor_v4.sh..."

cat << 'EOF' > final_extreme_monitor_v4.sh
#!/usr/bin/env bash
set -e

# final_extreme_monitor_v4.sh
#
# Example advanced script to build images, remove old containers,
# do logs analysis, CPU/mem usage, and optional AI summary placeholder.

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

vots_mistakes_log="vots_mistakes.log"

info()  { echo -e "${MATRIX_GREEN}[INFO] $*${RESET}"; }
note()  { echo -e "${MATRIX_DARKGREEN}[NOTE] $*${RESET}"; }
warn()  { echo -e "${YELLOW}[WARN] $*${RESET}"; echo "$(date) [WARN] $*" >> "$vots_mistakes_log"; }
err()   { echo -e "${RED}[ERROR] $*${RESET}"; echo "$(date) [ERROR] $*" >> "$vots_mistakes_log"; exit 1; }

# ASCII banner
echo -e "${MATRIX_GREEN} __      ___   ___ _____ "
echo -e " \\ \\    / / | | |_ _|_   _|"
echo -e "  \\ \\/\\/ /| | | || |  | |  "
echo -e "   \\_/\\_/ | |_| || |  | |  "
echo -e "         |_____|___| |_|  ${RESET}"
echo -e "${MATRIX_DARKGREEN}--- final_extreme_monitor_v4.sh (VOTS) ---${RESET}"

info "Removing old containers for: solana_agents ragchain_service quant_service..."
docker ps -a | grep -E 'solana_agents|ragchain_service|quant_service' | awk '{print $1}' | xargs -r docker rm -f || true

info "Building Docker images (no explicit --no-cache used)..."
docker compose build

info "Starting containers in detached mode..."
docker compose up -d

# Wait up to 90s for 'healthy'
MAX_WAIT=90
start_time=$(date +%s)
while true; do
  all_healthy=true
  for svc in solana_agents ragchain_service quant_service; do
    cid=$(docker compose ps -q "$svc")
    if [ -z "$cid" ]; then
      warn "No container found for service: $svc"
      all_healthy=false
      continue
    fi
    status=$(docker inspect --format='{{.State.Health.Status}}' "$cid" 2>/dev/null || echo "missing")
    if [ "$status" != "healthy" ]; then
      all_healthy=false
      break
    fi
  done
  if $all_healthy; then
    info "All requested Docker services report 'healthy'!"
    break
  fi
  elapsed=$(( $(date +%s) - start_time ))
  if [ $elapsed -ge $MAX_WAIT ]; then
    warn "Not all containers became healthy within $MAX_WAIT seconds."
    break
  fi
  sleep 5
done

note "Performing container port checks with 'nc -z localhost'..."
declare -A PORT_MAP=( ["solana_agents"]="4000" ["ragchain_service"]="5000" ["quant_service"]="7000" )
for svc in "${!PORT_MAP[@]}"; do
  port="${PORT_MAP[$svc]}"
  if nc -z localhost "$port"; then
    info "$svc => host port $port is open"
  else
    warn "$svc => host port $port not open"
  fi
done

note "Checking /health endpoints on localhost..."
for svc in "${!PORT_MAP[@]}"; do
  port="${PORT_MAP[$svc]}"
  if curl -sf "http://localhost:$port/health" >/dev/null; then
    info "$svc => /health responded OK on localhost:$port"
  else
    warn "$svc => /health check failed on localhost:$port"
  fi
done

info "Analyzing last 100 lines of logs for keywords: error exception traceback fail"
KEYWORDS="error|exception|traceback|fail"
for svc in solana_agents ragchain_service quant_service; do
  cid=$(docker compose ps -q "$svc" || true)
  if [ -z "$cid" ]; then
    warn "No container for $svc, skipping logs."
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

info "Checking container CPU/Memory usage with 'docker stats --no-stream'..."
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

info "Final system resource usage..."
LOAD_AVG=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
info "CPU Load (1/5/15): $LOAD_AVG"

mem_info=$(free -m | awk '/Mem:/{printf "%dMB used / %dMB total (%.1f%%)", $3, $2, ($3*100/$2)}')
info "Memory Usage: $mem_info"

swap_info=$(free -m | awk '/Swap:/{printf "%dMB used / %dMB total", $3, $2}')
swap_total=$(echo "$swap_info" | awk '{print $6}')
if [ "$swap_total" = "0" ]; then
  info "Swap Usage: 0MB used / 0MB total (0%)"
else
  used=$(echo "$swap_info" | awk '{print $1}')
  total=$(echo "$swap_info" | awk '{print $5}')
  pct=$(awk -v used="$used" -v total="$total" 'BEGIN {printf "%.1f", used*100/total}')
  info "Swap Usage: ${used}MB used / ${total}MB total (${pct}%)"
fi

disk_usage=$(df -h / | awk 'NR==2{print $5 " used on /"}')
info "Disk Usage on /: $disk_usage"

if [ -z "$OPENAI_API_KEY" ]; then
  warn "OPENAI_API_KEY not set, skipping AI summary."
else
  note "Minimal AI summary placeholder - customize further if needed."
  echo "--- End of AI Summary ---"
fi

note "final_extreme_monitor_v4.sh complete! Check vots_mistakes.log if needed."
EOF

echo "[INFO] Done! You can now run: 'docker compose build' then 'docker compose up -d' to start."
echo "[INFO] Then, run './final_extreme_monitor_v4.sh' to test build & logs analysis."

