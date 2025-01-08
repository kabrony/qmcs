#!/usr/bin/env bash
#
# setup_sol_ai_stack_clean.sh
# Creates a multi-service "sol_ai_stack_clean" WITHOUT container_name lines,
# so Docker auto-generates container names and avoids conflicts.

echo "[INFO] Creating 'sol_ai_stack_clean' folder..."
mkdir -p sol_ai_stack_clean
cd sol_ai_stack_clean || {
  echo "[ERROR] Could not cd into sol_ai_stack_clean!"
  exit 1
}

# 1) docker-compose.yml (no container_name)
cat > docker-compose.yml <<'DCOMP'
version: "3.9"

services:
  openai_service:
    build:
      context: ./openai_service
      dockerfile: Dockerfile
    restart: always
    ports:
      - "3001:3001"
    networks:
      - sol-ai-net

  solana_agents:
    build:
      context: ./solana_agents
      dockerfile: Dockerfile
    restart: always
    ports:
      - "4000:4000"
    networks:
      - sol-ai-net

  solana_trader:
    build:
      context: ./solana_trader
      dockerfile: Dockerfile
    restart: always
    ports:
      - "4500:4500"
    networks:
      - sol-ai-net

  quant_service:
    build:
      context: ./quant_service
      dockerfile: Dockerfile
    restart: always
    ports:
      - "7000:7000"
    networks:
      - sol-ai-net

  ragchain_service:
    build:
      context: ./ragchain_service
      dockerfile: Dockerfile
    restart: always
    ports:
      - "5000:5000"
    depends_on:
      - mongo
    networks:
      - sol-ai-net

  oracle_service:
    build:
      context: ./oracle_service
      dockerfile: Dockerfile
    restart: always
    ports:
      - "6000:6000"
    networks:
      - sol-ai-net

  mongo:
    image: mongo:latest
    restart: always
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db
    networks:
      - sol-ai-net

volumes:
  mongo_data:

networks:
  sol-ai-net:
    name: sol-ai-clean-network
DCOMP

# 2) Create subfolders and sample Dockerfiles/code
mkdir -p openai_service solana_agents solana_trader quant_service ragchain_service oracle_service

# openai_service
cat > openai_service/Dockerfile <<'DOCK'
FROM python:3.10-slim
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential curl && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir openai fastapi uvicorn

COPY . /app
EXPOSE 3001

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "3001"]
DOCK

cat > openai_service/main.py <<'PY'
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"message": "OpenAI Service (auto-named container)"}
PY

# solana_agents
cat > solana_agents/Dockerfile <<'DOCK'
FROM node:18-slim
WORKDIR /app

COPY package.json ./
RUN npm install
COPY . /app

EXPOSE 4000
CMD ["node", "index.js"]
DOCK

cat > solana_agents/package.json <<'PKG'
{
  "name": "solana_agents",
  "version": "1.0.0",
  "dependencies": {}
}
PKG

cat > solana_agents/index.js <<'JS'
const http = require('http');
const PORT = 4000;

http.createServer((req, res) => {
  res.writeHead(200, {"Content-Type": "text/plain"});
  res.end("Solana Agents (auto-named) on port 4000");
}).listen(PORT, () => {
  console.log("[solana_agents] Listening on", PORT);
});
JS

# solana_trader
cat > solana_trader/Dockerfile <<'DOCK'
FROM python:3.10-slim
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential curl && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir requests

COPY . /app
EXPOSE 4500

CMD ["python", "trader.py"]
DOCK

cat > solana_trader/trader.py <<'PY'
import time

print("[solana_trader] starting on 4500")
while True:
    print("[solana_trader] logic run")
    time.sleep(10)
PY

# quant_service
cat > quant_service/Dockerfile <<'DOCK'
FROM python:3.10-slim
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential curl && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir requests fastapi uvicorn numpy pandas

COPY . /app
EXPOSE 7000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7000"]
DOCK

cat > quant_service/main.py <<'PY'
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def home():
    return {"status": "Quant Service (auto-named) on port 7000"}
PY

# ragchain_service
cat > ragchain_service/Dockerfile <<'DOCK'
FROM python:3.10-slim
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential curl && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir motor fastapi uvicorn requests tenacity

COPY . /app
EXPOSE 5000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
DOCK

cat > ragchain_service/main.py <<'PY'
import os
from fastapi import FastAPI
from motor.motor_asyncio import AsyncIOMotorClient
from tenacity import retry, stop_after_attempt, wait_fixed

app = FastAPI()
MONGO_URL = os.getenv("MONGO_URL", "mongodb://mongo:27017")

db_client = None

@retry(stop=stop_after_attempt(5), wait=wait_fixed(2))
async def connect_to_mongo():
    global db_client
    db_client = AsyncIOMotorClient(MONGO_URL)
    pong = await db_client.admin.command("ping")
    print("[ragchain_service] Mongo ping:", pong)

@app.on_event("startup")
async def startup_event():
    await connect_to_mongo()
    print("[ragchain_service] Connected to Mongo via Motor")

@app.get("/")
async def home():
    return {"msg": "ragchain_service (auto-named) on port 5000"}
PY

# oracle_service
cat > oracle_service/Dockerfile <<'DOCK'
FROM node:18-slim
WORKDIR /app

COPY package.json ./
RUN npm install
COPY . /app

EXPOSE 6000
CMD ["node", "oracle.js"]
DOCK

cat > oracle_service/package.json <<'PKG'
{
  "name": "oracle_service",
  "version": "1.0.0",
  "dependencies": {}
}
PKG

cat > oracle_service/oracle.js <<'JS'
const http = require('http');
const PORT = 6000;

http.createServer((req, res) => {
  res.writeHead(200, {"Content-Type": "application/json"});
  res.end(JSON.stringify({status: "Oracle (auto-named) on port 6000"}));
}).listen(PORT, () => {
  console.log("[oracle_service] on port", PORT);
});
JS

echo "=========================================================="
echo "[SUCCESS] 'sol_ai_stack_clean' folder is ready."
echo "No container_name => Docker auto-names => no conflicts."
echo "Next steps:"
echo "  cd sol_ai_stack_clean"
echo "  docker-compose up --build -d     # bring up all"
echo "or docker-compose up --build -d openai_service solana_agents etc."
echo "=========================================================="
