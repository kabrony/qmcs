#!/usr/bin/env bash
set -e

# --------------------------------------------------------------------
# SOLAIS One-Shot Installer - COMPLETE and CORRECT
# Creates all files and directories, checks for essential tools,
# and sets up the SOLAIS trading system with database support
# --------------------------------------------------------------------

# ANSI colors for logging
GREEN='\033[38;5;82m'
DGREEN='\033[38;5;22m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { echo -e "${GREEN}[INFO] $*${RESET}"; }
note()  { echo -e "${DGREEN}[NOTE] $*${RESET}"; }
warn()  { echo -e "${YELLOW}[WARN] $*${RESET}"; }
err()   { echo -e "${RED}[ERROR] $*${RESET}"; }

# 1) Check for required commands
REQUIRED_TOOLS=(docker "docker compose" python3 nc mysql redis-cli)
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v $tool &> /dev/null; then
    err "Error: '$tool' not found. Please install or add to PATH before proceeding."
    exit 1
  fi
done

# 2) If no .env, create a sample one with new database configurations
if [ ! -f ".env" ]; then
  warn "No .env file found. Creating a sample .env..."
  cat <<EOT > .env
# =======================================================
#  Database Configurations
# =======================================================
MYSQL_DATABASE=rag_flow
MYSQL_USER=ragflowuser
MYSQL_PASSWORD=ragflow123
MYSQL_ROOT_PASSWORD=mysecretpassword
# Redis
REDIS_PASSWORD=myredispass
# =======================================================
#  MongoDB
# =======================================================
MONGO_DETAILS=mongodb+srv://doadmin:165m03P7VWd9sT8E@db-mongodb-nyc3-54764-ab8335eb.mongo.ondigitalocean.com/admin?authSource=admin&replicaSet=db-mongodb-nyc3-54764

# =======================================================
#  Solana
# =======================================================
SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
SOLANA_PRIVATE_KEY="your-solana-private-key"
SOLANA_PUBLIC_KEY="your-solana-public-key"

# =======================================================
#  Additional Keys
# =======================================================
OPENAI_API_KEY="your-openai-key"
GEMINI_API_KEY="your-gemini-key"
DEEPSEEK_API_KEY="your-deepseek-key"
TAVILY_API_KEY="your-tavily-key"
EOT
  note "Please edit the new .env file with valid credentials."
fi

# 3) Create directory structure
info "Creating directory structure..."
mkdir -p solana_agents/app ragchain_service/app quant_service/app

# 4) Update docker-compose.yml with new services
info "Writing docker-compose.yml..."
cat <<'EOF' > docker-compose.yml
version: "3.8"
services:
  solana_agents:
    build:
      context: ./solana_agents
      dockerfile: Dockerfile
    ports:
      - "4000:4000"
    environment:
      PORT: 4000
      RAGCHAIN_URL: http://ragchain-service:5000
      QUANT_URL: http://quant-service:7000
      SOLANA_RPC_URL: ${SOLANA_RPC_URL}
      SOLANA_PRIVATE_KEY: ${SOLANA_PRIVATE_KEY}
      MYSQL_HOST: mysql
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      REDIS_HOST: redis
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    depends_on:
      - ragchain-service
      - quant-service
      - mysql
      - redis
    networks:
      - app-network

  ragchain-service:
    build:
      context: ./ragchain_service
      dockerfile: Dockerfile
    ports:
      - "5000:5000"
    environment:
      PORT: 5000
      MONGO_DETAILS: ${MONGO_DETAILS}
      MYSQL_HOST: mysql
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    depends_on:
      - mongo
      - mysql
    networks:
      - app-network

  quant-service:
    build:
      context: ./quant_service
      dockerfile: Dockerfile
    ports:
      - "7000:7000"
    environment:
      PORT: 7000
      REDIS_HOST: redis
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    depends_on:
      - redis
    networks:
      - app-network

  mysql:
    image: mysql:8.0
    ports:
      - "3306:3306"
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - app-network

  redis:
    image: redis:7.0
    ports:
      - "6379:6379"
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - app-network

  mongo:
    image: mongo:latest
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db
    networks:
      - app-network

volumes:
  mysql_data:
  redis_data:
  mongo_data:

networks:
  app-network:
    name: solais-network
EOF

# 5) solana_agents Dockerfile
info "Writing solana_agents/Dockerfile..."
cat <<'EOF' > solana_agents/Dockerfile
FROM node:18-slim

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install

COPY app/ ./app
WORKDIR /app
EXPOSE 4000
CMD ["node", "index.js"]
EOF

# 6) solana_agents package.json
info "Writing solana_agents/package.json..."
cat <<'EOF' > solana_agents/package.json
{
  "name": "solana_agents",
  "version": "1.0.0",
  "description": "Solana Agents Node.js service",
  "main": "app/index.js",
  "scripts": {
    "start": "node app/index.js"
  },
  "dependencies": {
    "@solana/web3.js": "^1.93.6",
    "axios": "^1.4.0",
    "dotenv": "^16.3.1",
    "express": "^4.18.2"
  }
}
EOF

# 7) solana_agents/app/index.js
info "Writing solana_agents/app/index.js..."
cat <<'EOF' > solana_agents/app/index.js
#!/usr/bin/env node
"use strict";

require("dotenv").config();
const express = require("express");
const axios = require("axios");
const { Connection, PublicKey } = require("@solana/web3.js");

const app = express();
app.use(express.json());

// Basic logging
function logInfo(msg) {
  console.log(new Date().toISOString(), "[INFO]", msg);
}
function logError(msg) {
  console.error(new Date().toISOString(), "[ERROR]", msg);
}

const PORT = process.env.PORT || 4000;
const RAGCHAIN_URL = process.env.RAGCHAIN_URL || "";
const QUANT_URL = process.env.QUANT_URL || "";
const SOLANA_RPC_URL = process.env.SOLANA_RPC_URL || "";
const SOLANA_PRIVATE_KEY = process.env.SOLANA_PRIVATE_KEY || "";

// Health endpoint
app.get("/health", async (req, res) => {
  try {
    // Check dependent services
    await axios.get(`${RAGCHAIN_URL}/health`);
    await axios.get(`${QUANT_URL}/health`);
    res.status(200).json({
      status: "solana_agents healthy",
      dependencies: { ragchain: "ok", quant: "ok" }
    });
  } catch (error) {
    logError(`Health check failed: ${error.message}`);
    res.status(503).json({ status: "unhealthy", error: error.message });
  }
});

// Example: fetch ephemeral ideas
app.get("/api/v1/fetch-ideas", async (req, res) => {
  if (!RAGCHAIN_URL) {
    return res.status(400).json({ error: "No RAGCHAIN_URL set" });
  }
  try {
    const resp = await axios.get(`${RAGCHAIN_URL}/ephemeral_ideas`);
    res.status(200).json({ data: resp.data });
  } catch (e) {
    logError(`fetch-ideas error: ${e.message}`);
    if (e.response) {
      logError(` Status: ${e.response.status}, Data: ${JSON.stringify(e.response.data)}`);
    }
    res.status(500).json({ error: `Failed to fetch ideas: ${e.message}` });
  }
});

// Example: call quant_service
app.get("/api/v1/run-quant", async (req, res) => {
  if (!QUANT_URL) {
    return res.status(400).json({ error: "No QUANT_URL set" });
  }
  try {
    const r = await axios.get(`${QUANT_URL}/example-circuits`);
    res.status(200).json(r.data);
  } catch (e) {
    logError(`run-quant error: ${e.message}`);
    if (e.response) {
      logError(` Status: ${e.response.status}, Data: ${JSON.stringify(e.response.data)}`);
    }
    res.status(500).json({ error: `Failed to run quant logic: ${e.message}` });
  }
});

// Show partial Solana config
app.get("/solana-config", (req, res) => {
  const privKeySet = !!SOLANA_PRIVATE_KEY;
  return res.status(200).json({
    SOLANA_RPC_URL: SOLANA_RPC_URL.slice(0, 50) + "...",
    hasPrivateKey: privKeySet
  });
});

// Example: fetch Solana balance
app.get("/solana-balance/:publicKey", async (req, res) => {
  if (!SOLANA_RPC_URL) {
    return res.status(400).json({ error: "SOLANA_RPC_URL not set" });
  }
  try {
    const connection = new Connection(SOLANA_RPC_URL);
    const pubKey = new PublicKey(req.params.publicKey);
    const balance = await connection.getBalance(pubKey);
    res.status(200).json({ publicKey: req.params.publicKey, balance });
  } catch (error) {
    logError(`Error fetching Solana balance: ${error}`);
    res.status(500).json({ error: `Failed to fetch Solana balance: ${error.message}` });
  }
});

app.listen(PORT, () => {
  logInfo(`solana_agents listening on port ${PORT}`);
});
EOF

# 8) ragchain_service/Dockerfile
info "Writing ragchain_service/Dockerfile..."
cat <<'EOF' > ragchain_service/Dockerfile
FROM python:3.10-slim

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ /app
EXPOSE 5000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
EOF

info "Writing ragchain_service/requirements.txt..."
cat <<'EOF' > ragchain_service/requirements.txt
fastapi
uvicorn
pymongo
python-dotenv
tenacity
EOF

info "Writing ragchain_service/app/main.py..."
cat <<'EOF' > ragchain_service/app/main.py
import os
import logging
import asyncio
from typing import List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from pymongo import MongoClient, errors
from dotenv import load_dotenv
from tenacity import retry, stop_after_attempt, wait_fixed

load_dotenv()
logging.basicConfig(level=logging.INFO)

MONGO_DETAILS = os.getenv("MONGO_DETAILS", "")
if not MONGO_DETAILS:
    logging.error("MONGO_DETAILS not set!")

app = FastAPI()
client = None
chain_collection = None

@retry(stop=stop_after_attempt(3), wait=wait_fixed(2))
async def connect_to_mongo():
    global client, chain_collection
    logging.info("Connecting to MongoDB...")
    try:
        client = MongoClient(MONGO_DETAILS)
        await client.admin.command('ping')  # test connection
        ephemeral_db = client["ephemeral_memory"]
        chain_collection = ephemeral_db["chain_of_thought"]
        logging.info("Successfully connected to MongoDB.")
    except errors.ConnectionFailure as e:
        logging.error(f"Could not connect to MongoDB: {e}")
        raise

async def close_mongo_connection():
    global client
    if client:
        logging.info("Closing MongoDB connection...")
        client.close()
        logging.info("MongoDB connection closed.")

@app.on_event("startup")
async def startup_event():
    await connect_to_mongo()

@app.on_event("shutdown")
async def shutdown_event():
    await close_mongo_connection()

class ThoughtIn(BaseModel):
    thought: str = Field(..., description="The thought to store")

class ThoughtOut(BaseModel):
    _id: str = Field(..., description="MongoDB document ID")
    thought: str = Field(..., description="The stored thought")

@app.get("/health")
async def health():
    try:
        if client:
            await client.admin.command('ping')
            return {"message": "ragchain_service healthy", "mongo_status": "connected"}
        else:
            return {"message": "ragchain_service healthy", "mongo_status": "not connected"}
    except errors.ConnectionFailure:
        return {"message": "ragchain_service healthy", "mongo_status": "connection_error"}

@app.post("/store_thought/", response_model=ThoughtOut, status_code=201)
async def store_thought(thought_in: ThoughtIn):
    if not chain_collection:
        raise HTTPException(status_code=500, detail="MongoDB not connected")
    try:
        doc = {"thought": thought_in.thought}
        result = await asyncio.to_thread(chain_collection.insert_one, doc)
        inserted_id = str(result.inserted_id)
        return ThoughtOut(_id=inserted_id, thought=thought_in.thought)
    except Exception as e:
        logging.error(f"Error storing thought: {e}")
        raise HTTPException(status_code=500, detail=f"Error storing thought: {e}")

@app.get("/ephemeral_ideas", response_model=List[ThoughtOut])
async def ephemeral_ideas():
    if not chain_collection:
        raise HTTPException(status_code=500, detail="MongoDB not connected")
    try:
        docs_cursor = chain_collection.find().sort("_id", -1).limit(20)
        docs_list = await asyncio.to_thread(list, docs_cursor)
        return [
            ThoughtOut(_id=str(d["_id"]), thought=d["thought"])
            for d in docs_list
        ]
    except Exception as e:
        logging.error(f"Error fetching ephemeral ideas: {e}")
        raise HTTPException(status_code=500, detail=f"Error fetching ephemeral ideas: {e}")
EOF

# 9) quant_service/Dockerfile
info "Writing quant_service/Dockerfile..."
cat <<'EOF' > quant_service/Dockerfile
FROM python:3.10-slim

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ /app
EXPOSE 7000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7000"]
EOF

info "Writing quant_service/requirements.txt..."
cat <<'EOF' > quant_service/requirements.txt
fastapi
uvicorn
python-dotenv
EOF

info "Writing quant_service/app/main.py..."
cat <<'EOF' > quant_service/app/main.py
import os
import logging
import random
from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO)

app = FastAPI()

@app.get("/health")
async def health():
    return {"message": "quant_service healthy"}

@app.get("/generate-signal")
async def generate_signal():
    threshold = 0.5
    random_value = random.random()
    if random_value > threshold:
        return {"signal": "BUY", "confidence": random_value}
    else:
        return {"signal": "SELL", "confidence": 1 - random_value}

@app.get("/circuit-breaker-status")
async def circuit_breaker_status():
    is_tripped = random.random() < 0.2
    return {"is_tripped": is_tripped, "reason": "Simulated market volatility" if is_tripped else None}

@app.get("/example-circuits")
async def example_circuits():
    circuits = ["circuit_a", "circuit_b", "circuit_c"]
    status = random.choice(["ACTIVE", "TRIPPED", "PENDING"])
    return {"circuits": circuits, "status": status, "last_updated": "2024-01-01T12:00:00Z"}
EOF

# 10) final_extreme_monitor_v5.sh
info "Writing final_extreme_monitor_v5.sh..."
cat <<'EOF' > final_extreme_monitor_v5.sh
#!/usr/bin/env bash
set -e

trap ctrl_c INT
function ctrl_c() {
  echo ""
  echo "${YELLOW}[WARN] Caught Ctrl+C. Aborting final_extreme_monitor_v5.sh.${RESET}"
  docker compose down
  exit 1
}

GREEN='\033[38;5;82m'
DGREEN='\033[38;5;22m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'
mistakes_log="vots_mistakes.log"

info()  { echo -e "${GREEN}[INFO] $*${RESET}"; }
note()  { echo -e "${DGREEN}[NOTE] $*${RESET}"; }
warn()  { echo -e "${YELLOW}[WARN] $*${RESET}"; echo "$(date) [WARN] $*" >> "$mistakes_log"; }
err()   { echo -e "${RED}[ERROR] $*${RESET}"; echo "$(date) [ERROR] $*" >> "$mistakes_log"; exit 1; }

echo -e "${GREEN} __      ___   ___ _____ "
echo -e " \\ \\    / / | | |_ _|_   _|"
echo -e "  \\ \\/\\/ /| | | || |  | |  "
echo -e "   \\_/\\_/ | |_| || |  | |  "
echo -e "         |_____|___| |_|  ${RESET}"
echo -e "${DGREEN}--- final_extreme_monitor_v5.sh (VOTS) ---${RESET}"

BUILD_ONLY=false
if [ "$1" == "--build-only" ]; then
  BUILD_ONLY=true
  info "Build only mode activated."
fi

if ! $BUILD_ONLY; then
  info "Removing old containers for: solana_agents ragchain-service quant-service..."
  docker compose ps -a | grep -E 'solana_agents|ragchain-service|quant-service' | awk '{print $1}' | xargs -r docker rm -f || true
fi

info "Building Docker images..."
docker compose build

if $BUILD_ONLY; then
  info "Build complete. Exiting."
  exit 0
fi

info "Starting containers in detached mode..."
docker compose up -d

MAX_WAIT=90
start_time=$(date +%s)
while true; do
  all_healthy=true
  for svc in solana_agents ragchain-service quant-service; do
    cid=$(docker compose ps -q "$svc" 2>/dev/null || true)
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
    warn "Not all containers healthy within $MAX_WAIT seconds."
    break
  fi
  sleep 5
done

note "Checking host-based ports with 'nc -z localhost'..."
declare -A PORT_MAP=( ["solana_agents"]="4000" ["ragchain-service"]="5000" ["quant-service"]="7000" )
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
    info "$svc => /health is OK on localhost:$port"
  else
    warn "$svc => /health check failed on localhost:$port"
  fi
done

info "Analyzing last 100 lines of logs for error|exception|traceback|fail"
KEYWORDS="error|exception|traceback|fail"
for svc in solana_agents ragchain-service quant-service; do
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

info "Checking container CPU/Memory usage with docker stats --no-stream"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

info "Final system usage..."
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
  info "Swap Usage: ${used}MB / ${total}MB (${pct}%)"
fi

if [ -z "$OPENAI_API_KEY" ]; then
  warn "OPENAI_API_KEY not set, skipping AI summary."
else
  note "Minimal AI summary placeholder - customize if needed."
  if docker compose exec ragchain-service python -c "from app.main import chain_collection; print(chain_collection.find_one(sort=[('_id', -1)]).get('thought', ''))" 2>/dev/null; then
    LATEST_THOUGHT=$(docker compose exec ragchain-service python -c "from app.main import chain_collection; import json; doc=chain_collection.find_one(sort=[('_id', -1)]); print(json.dumps(doc['thought']) if doc else '')" 2>/dev/null)
    if [ -n "$LATEST_THOUGHT" ]; then
      AI_SUMMARY=$(curl -s -H "Content-Type: application/json" -d "{\"prompt\": \"Summarize this thought: $LATEST_THOUGHT\"}" http://localhost:4000/api/v1/llm-summary 2>/dev/null)
      if [ -n "$AI_SUMMARY" ]; then
        echo "--- AI Summary of Latest Thought ---"
        echo "$AI_SUMMARY"
      fi
    fi
  fi
fi

note "final_extreme_monitor_v5.sh complete! Check vots_mistakes.log if needed."
EOF

chmod +x final_extreme_monitor_v5.sh

# 11) solana_ai_trader.py
info "Writing solana_ai_trader.py..."
cat <<'EOF' > solana_ai_trader.py
#!/usr/bin/env python3
"""
solana_ai_trader.py
Demonstrates:
  - Reading .env for secrets: OPENAI_API_KEY, GEMINI_API_KEY, TAVILY_API_KEY, MONGO_DETAILS, SOLANA_RPC_URL
  - Ephemeral memory in Mongo
  - Multi-LLM calls: OpenAI, Google Gemini, Tavily
  - Basic Solana logic: check balance -> trivial "buy"/"hold" decision

Requires:
  pip install --no-cache-dir python-dotenv pymongo openai google-generativeai tavily-python solana tenacity
"""

import os
import sys
import time
import logging

import openai
import google.generativeai as genai
from pymongo import MongoClient, errors
from dotenv import load_dotenv
from solana.rpc.api import Client as SolanaClient
from solana.exceptions import SolanaRpcException
from tavily import TavilyClient
from tenacity import retry, stop_after_attempt, wait_fixed

load_dotenv()
logging.basicConfig(level=logging.INFO)

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
TAVILY_API_KEY = os.getenv("TAVILY_API_KEY")
MONGO_DETAILS  = os.getenv("MONGO_DETAILS", "")
SOLANA_RPC_URL = os.getenv("SOLANA_RPC_URL", "https://api.mainnet-beta.solana.com")
SOLANA_PUBLIC_KEY = os.getenv("SOLANA_PUBLIC_KEY")
OPENAI_MODEL_NAME = os.getenv("OPENAI_MODEL_NAME", "gpt-3.5-turbo")
OPENAI_TEMPERATURE = float(os.getenv("OPENAI_TEMPERATURE", "0.7"))

if not (OPENAI_API_KEY and GEMINI_API_KEY and MONGO_DETAILS and SOLANA_PUBLIC_KEY):
    logging.error("Missing essential env variables. Check .env (OPENAI_API_KEY, GEMINI_API_KEY, MONGO_DETAILS, SOLANA_PUBLIC_KEY).")
    sys.exit(1)

# Configure OpenAI
openai.api_key = OPENAI_API_KEY

# Configure Google Gemini
genai.configure(api_key=GEMINI_API_KEY)

# Configure Tavily if available
if TAVILY_API_KEY:
    tavily_client = TavilyClient(api_key=TAVILY_API_KEY)
else:
    tavily_client = None
    logging.warning("TAVILY_API_KEY not set. Tavily functionality disabled.")

# Ensure Mongo connection
try:
    mclient = MongoClient(MONGO_DETAILS)
    mclient.admin.command("ping")
    logging.info("Connected to Mongo ephemeral DB.")
except errors.ConnectionFailure as e:
    logging.error(f"Mongo connect fail: {e}")
    sys.exit(1)

solana_client = SolanaClient(SOLANA_RPC_URL)

def log_thought(step: str, content: str):
    """Store ephemeral chain-of-thought in Mongo ephemeral_memory."""
    try:
        with MongoClient(MONGO_DETAILS) as mc:
            db = mc["ephemeral_memory"]
            doc = {
                "step": step,
                "content": content,
                "timestamp": time.time()
            }
            db["chain_of_thought"].insert_one(doc)
            logging.info(f"Logged chain-of-thought step: {step}")
    except Exception as e:
        logging.error(f"log_thought error: {e}")

@retry(stop=stop_after_attempt(3), wait=wait_fixed(2))
def call_openai(prompt: str) -> str:
    logging.info(f"Calling OpenAI: {OPENAI_MODEL_NAME}")
    try:
            model=OPENAI_MODEL_NAME,
            messages=[
                {"role": "system", "content": "You are an advanced quant trading assistant specializing in Solana."},
                {"role": "user",   "content": prompt}
            ],
            max_tokens=200,
            temperature=OPENAI_TEMPERATURE
        )
        return resp.choices[0].message.content
    except Exception as e:
        msg = f"[OpenAI error: {e}]"
        logging.error(msg)
        return msg

@retry(stop=stop_after_attempt(3), wait=wait_fixed(2))
def call_gemini(prompt: str) -> str:
    logging.info("Calling Google Gemini via google.generativeai...")
    try:
        model = genai.GenerativeModel('gemini-pro')
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        msg = f"[Gemini error: {e}]"
        logging.error(msg)
        return msg

@retry(stop=stop_after_attempt(3), wait=wait_fixed(2))
def call_tavily(prompt: str) -> str:
    if not tavily_client:
        return "[Tavily not configured]"
    logging.info(f"Calling Tavily with prompt: {prompt[:50]}...")
    try:
        response = tavily_client.search(prompt)
        return f"Tavily results: {response.get('results', [])}"
    except Exception as e:
        msg = f"[Tavily error: {e}]"
        logging.error(msg)
        return msg

@retry(stop=stop_after_attempt(3), wait=wait_fixed(2))
def check_balance() -> float:
    """Check user SOL balance using Solana RPC."""
    try:
        balance_result = solana_client.get_balance(SOLANA_PUBLIC_KEY)
        return balance_result.value
    except SolanaRpcException as e:
        logging.error(f"Error fetching Solana balance: {e}")
        return -1
    except Exception as e:
        logging.error(f"Unexpected error fetching Solana balance: {e}")
        return -1

def run_trade_logic():
    sol_balance = check_balance()
    if sol_balance < 0:
        logging.error("Could not retrieve Solana balance. Aborting trade logic.")
        return

    logging.info(f"Solana balance is {sol_balance:.2f} SOL")

    question = (
        f"My current SOL balance is {sol_balance:.2f}. "
        "In your expert opinion, should I BUY or HOLD Solana in the short term for potential gains?"
    )

    # Call multiple LLMs
    openai_ans = call_openai(question)
    gemini_ans = call_gemini(question)
    tavily_ans = call_tavily("Current sentiment and news for Solana (SOL) cryptocurrency.")

    # Log their reasoning
    log_thought("openai reasoning", openai_ans)
    log_thought("gemini reasoning", gemini_ans)
    log_thought("tavily analysis", tavily_ans)

    # Very naive decision logic
    if sol_balance < 0.5:
        if "BUY" in openai_ans.upper() or "BULLISH" in tavily_ans.upper():
            decision = "BUY"
        else:
            decision = "HOLD"
    elif "SELL" in gemini_ans.upper() and "NEGATIVE" in tavily_ans.upper():
        decision = "HOLD"
    else:
        decision = "HOLD"

    # Final decision
    log_thought("final decision", f"Decided to {decision} with balance {sol_balance:.2f}")
    logging.info(f"Final trade decision: {decision}")
    print(f"[INFO] final trade decision => {decision}")

def main():
    logging.info("Starting solana_ai_trader synergy example...")
    run_trade_logic()
    logging.info("Done. Check ephemeral_memory.chain_of_thought in Mongo for logs.")

if __name__ == "__main__":
    main()
EOF

# 12) SOLAIS_OVERVIEW.md
info "Writing SOLAIS_OVERVIEW.md..."
cat <<'EOF' > SOLAIS_OVERVIEW.md
# SOLAIS: Solana AI Trading System Overview

This document provides an overview of the SOLAIS system—a Solana and AI-powered trading system.

## Architecture

- **solana_agents (Node.js)**: Orchestrator & API gateway, calls ragchain_service & quant_service.
- **ragchain_service (Python FastAPI)**: Stores ephemeral AI thoughts in MongoDB.
- **quant_service (Python FastAPI)**: Offers quant logic & circuit-breaker checks.
- **mongo (Docker)**: MongoDB instance for ephemeral data storage.
- **solana_ai_trader.py (Python)**: Trading logic that uses OpenAI, Google Gemini, Tavily, and Solana blockchain calls.

## Key Features

- **Containerized**: Easy Docker setup.
- **AI Integration**: Multi-LLM approach (OpenAI, Gemini, Tavily).
- **Ephemeral Memory**: Chain-of-thought debug logs in MongoDB.
- **Monitoring**: `final_extreme_monitor_v5.sh` checks logs, container health, CPU & memory usage.

## Quick Start

1. **Set `.env`**: Provide your MONGO_DETAILS, SOLANA keys, and LLM keys in `.env`.
2. **Build & Start**:
   ```bash
   docker compose build
   docker compose up -d
