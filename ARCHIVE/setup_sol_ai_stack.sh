#!/usr/bin/env bash
#
# setup_sol_ai_stack.sh
#
# Creates a multi-service Docker Compose project with:
#   1) openai_service
#   2) solana_agents
#   3) solana_trader
#   4) quant_service
#   5) ragchain_service (async Mongo)
#   6) oracle_service
# 
# Each uses 'restart: always' so they stay running after VM restarts
# (assuming Docker starts on boot).
#
# Usage:
#   chmod +x setup_sol_ai_stack.sh
#   ./setup_sol_ai_stack.sh
#   cd sol_ai_stack
#   docker-compose up --build -d
#
# Then check logs:
#   docker-compose logs -f
#

################################################################################
# 1) CREATE FOLDERS
################################################################################
mkdir -p sol_ai_stack
cd sol_ai_stack || exit 1

mkdir -p openai_service
mkdir -p solana_agents
mkdir -p solana_trader
mkdir -p quant_service
mkdir -p ragchain_service
mkdir -p oracle_service

################################################################################
# 2) docker-compose.yml
################################################################################
cat > docker-compose.yml <<DOCKERCOMPOSE
version: "3.9"

services:
  openai_service:
    build:
      context: ./openai_service
      dockerfile: Dockerfile
    container_name: openai_service
    restart: always
    ports:
      - "3001:3001"
    networks:
      - sol-ai-net

  solana_agents:
    build:
      context: ./solana_agents
      dockerfile: Dockerfile
    container_name: solana_agents
    restart: always
    ports:
      - "4000:4000"
    networks:
      - sol-ai-net

  solana_trader:
    build:
      context: ./solana_trader
      dockerfile: Dockerfile
    container_name: solana_trader
    restart: always
    ports:
      - "4500:4500"
    networks:
      - sol-ai-net

  quant_service:
    build:
      context: ./quant_service
      dockerfile: Dockerfile
    container_name: quant_service
    restart: always
    ports:
      - "7000:7000"
    networks:
      - sol-ai-net

  ragchain_service:
    build:
      context: ./ragchain_service
      dockerfile: Dockerfile
    container_name: ragchain_service
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
    container_name: oracle_service
    restart: always
    ports:
      - "6000:6000"
    networks:
      - sol-ai-net

  mongo:
    image: mongo:latest
    container_name: local_mongo
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
    name: sol-ai-network
DOCKERCOMPOSE

################################################################################
# 3) openai_service
################################################################################
cat > openai_service/Dockerfile <<DOCKERFILE
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && \\
    apt-get install -y --no-install-recommends build-essential curl && \\
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir openai fastapi uvicorn

COPY . /app

EXPOSE 3001

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "3001"]
DOCKERFILE

cat > openai_service/main.py <<PYTHON
import os
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"message": "OpenAI Service is running on port 3001"}
PYTHON

################################################################################
# 4) solana_agents (Node.js)
################################################################################
cat > solana_agents/Dockerfile <<DOCKERFILE
FROM node:18-slim
WORKDIR /app

COPY package.json ./
RUN npm install

COPY . /app

EXPOSE 4000

CMD ["node", "index.js"]
DOCKERFILE

cat > solana_agents/package.json <<PKGJSON
{
  "name": "solana_agents",
  "version": "1.0.0",
  "dependencies": {}
}
PKGJSON

cat > solana_agents/index.js <<NODEJS
const http = require('http');
const PORT = 4000;

http.createServer((req, res) => {
  res.writeHead(200, {"Content-Type": "text/plain"});
  res.end("Solana Agents running on port 4000");
}).listen(PORT, () => {
  console.log("[INFO] solana_agents listening on port", PORT);
});
NODEJS

################################################################################
# 5) solana_trader (Python)
################################################################################
cat > solana_trader/Dockerfile <<DOCKERFILE
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && \\
    apt-get install -y --no-install-recommends build-essential curl && \\
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir requests

COPY . /app

EXPOSE 4500

CMD ["python", "trader.py"]
DOCKERFILE

cat > solana_trader/trader.py <<PYTHON
import time

print("Solana Trader starting on port 4500...")
while True:
    print("Solana Trader logic here...")
    time.sleep(10)
PYTHON

################################################################################
# 6) quant_service (Python FastAPI)
################################################################################
cat > quant_service/Dockerfile <<DOCKERFILE
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && \\
    apt-get install -y --no-install-recommends build-essential curl && \\
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir requests fastapi uvicorn numpy pandas

COPY . /app

EXPOSE 7000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7000"]
DOCKERFILE

cat > quant_service/main.py <<PYTHON
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def hello():
    return {"status": "Quant Service running on port 7000"}
PYTHON

################################################################################
# 7) ragchain_service (Async + Motor)
################################################################################
cat > ragchain_service/Dockerfile <<DOCKERFILE
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && \\
    apt-get install -y --no-install-recommends build-essential curl && \\
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir motor fastapi uvicorn tenacity

COPY . /app

EXPOSE 5000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
DOCKERFILE

cat > ragchain_service/main.py <<PYTHON
import os
from fastapi import FastAPI
from motor.motor_asyncio import AsyncIOMotorClient
from tenacity import retry, stop_after_attempt, wait_fixed

app = FastAPI()
MONGO_URL = os.getenv("MONGO_URL", "mongodb://mongo:27017")

db_client = None

@retry(stop=stop_after_attempt(5), wait=wait_fixed(2))
async def connect_mongo():
    global db_client
    db_client = AsyncIOMotorClient(MONGO_URL)
    result = await db_client.admin.command("ping")
    print("[ragchain_service] ping result:", result)

@app.on_event("startup")
async def startup_event():
    await connect_mongo()
    print("[ragchain_service] Connected to Mongo via Motor async")

@app.get("/")
async def home():
    return {"status": "Ragchain service running on port 5000"}
PYTHON

################################################################################
# 8) oracle_service (Node.js)
################################################################################
cat > oracle_service/Dockerfile <<DOCKERFILE
FROM node:18-slim
WORKDIR /app

COPY package.json ./
RUN npm install

COPY . /app

EXPOSE 6000

CMD ["node", "oracle.js"]
DOCKERFILE

cat > oracle_service/package.json <<PKGJSON
{
  "name": "oracle_service",
  "version": "1.0.0",
  "dependencies": {}
}
PKGJSON

cat > oracle_service/oracle.js <<NODEJS
const http = require('http');
const PORT = 6000;

http.createServer((req, res) => {
  res.writeHead(200, {"Content-Type": "application/json"});
  res.end(JSON.stringify({status: "Oracle running", data: {price: 42.0}}));
}).listen(PORT, () => {
  console.log("[INFO] oracle_service is up on port", PORT);
});
NODEJS

################################################################################
# 9) DONE
################################################################################
cd ..
echo "======================================================"
echo "[SUCCESS] sol_ai_stack created with multi-service setup."
echo "Next Steps:"
echo "  1) cd sol_ai_stack"
echo "  2) docker-compose up --build -d"
echo "Then services will run with 'restart: always'."
echo "Check logs: 'docker-compose logs -f'"
echo "======================================================"
