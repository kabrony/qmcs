#!/usr/bin/env bash
set -e

# FINAL script for multi-service Docker stack (Python + Node)
# Using 'cat' for file creation, no interactive editors
# Single entry point application with all dependencies in project root

#####################################
# 0) Docker checks
#####################################
if ! command -v docker &>/dev/null; then
  echo "[ERROR] Docker not found. Install Docker first."
  exit 1
fi
if ! command -v docker-compose &>/dev/null; then
  echo "[ERROR] docker-compose not found. Install docker-compose."
  exit 1
fi

#####################################
# 1) Optional Docker prune
#####################################
read -rp "[INFO] Prune old Docker resources first? [y/N]: " PRUNE
if [[ "$PRUNE" =~ ^[Yy]$ ]]; then
  docker-compose down || true
  docker system prune -af --volumes || true
fi

#####################################
# 2) Ensure python => python3 (Ubuntu/Debian)
#####################################
if ! command -v python &>/dev/null; then
  echo "[INFO] 'python' not found; installing python-is-python3..."
  sudo apt-get update -y && sudo apt-get install -y python-is-python3
fi

#####################################
# 3) .env handling
#####################################
ENV_FILE=".env"
if [[ -f "$ENV_FILE" ]]; then
  echo "[INFO] Found existing .env; leaving it as is."
else
  echo "[INFO] No .env found; creating a minimal placeholder..."
  cat <<EOF > "$ENV_FILE"
# Minimal .env
SAMPLE_ENV_VAR="YOUR_VALUE_HERE"
OPENAI_API_KEY="sk-" # ADD YOUR OPENAI API KEY HERE
EOF
fi

#####################################
# 4) Subfolders + minimal Dockerfiles
#####################################
# We define 2 categories: Python-based & Node-based
# "openai_service" "quant_service", "ragchain_service", "oracle_service", "argus_service" => Python
# "solana_agents" => Node

echo "[INFO] Creating openai_service folder and files"
if [[ ! -d "openai_service" ]]; then
    mkdir -p "openai_service"
fi

cat <<EOF > "openai_service/main.py"
import os
import openai
from dotenv import load_dotenv

def main():
    load_dotenv()
    client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

    response = client.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": "Say hello politely."}],
        temperature=0.7,
    )
    print("OpenAI response:", response.choices[0].message.content.strip())

if __name__ == "__main__":
    main()
EOF

cat <<EOF > "openai_service/requirements.txt"
openai==0.27.0
python-dotenv==1.0.0
EOF

cat <<EOF > "openai_service/Dockerfile"
FROM python:3.10-slim

WORKDIR /app

# Copy requirements first, then install
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . /app

# Final command to run your main.py
CMD ["python", "main.py"]
EOF

echo "[INFO] Creating other python service folders..."
PYTHON_SERVICES=("argus_service" "oracle_service"  "quant_service" "ragchain_service")
for service in "${PYTHON_SERVICES[@]}"; do
    if [[ ! -d "$service" ]]; then
        echo "[INFO] Creating folder: $service"
        mkdir -p "$service"
    fi
        echo "[INFO] Creating requirements.txt file for $service"
        cat <<EOF > "$service/requirements.txt"
fastapi
uvicorn
requests
python-dotenv
pydantic
httpx
EOF
     if [[ ! -f "$service/Dockerfile" ]]; then
        echo "[INFO] Creating minimal Dockerfile in $service"
        cat <<EOF > "$service/Dockerfile"
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt
COPY . /app
CMD ["python", "main.py"] # Adjust your entrypoint as needed
EOF
     fi
     if [[ ! -f "$service/main.py" ]]; then
        echo "[INFO] Creating main.py for $service"
        cat <<EOF > "$service/main.py"
import os
from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "Hello from $service"}
EOF
    fi
done


NODE_SERVICES=("solana_agents")
for service in "${NODE_SERVICES[@]}"; do
    if [[ ! -d "$service" ]]; then
        echo "[INFO] Creating missing folder: $service"
        mkdir -p "$service"
    fi
      echo "[INFO] Creating minimal package.json in $service"
    cat <<EOF > "$service/package.json"
{
  "name": "$service",
  "version": "1.0.0",
  "description": "Minimal Node service",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
        "dotenv": "^16.3.1",
        "axios": "^1.6.2",
        "@solana/web3.js": "^1.90.0",
        "ws": "^8.16.0",
        "node-fetch": "^3.3.2",
        "form-data": "^4.0.0",
        "node-cron": "^3.0.2",
        "express": "^4.18.2"
      }
}
EOF
    if [[ ! -f "$service/Dockerfile" ]]; then
         echo "[INFO] Creating minimal Dockerfile in $service"
        cat <<EOF > "$service/Dockerfile"
FROM node:18-slim
WORKDIR /app
COPY package.json /app/
RUN npm install
COPY . /app
CMD ["npm", "start"] # Adjust your entrypoint as needed
EOF
     fi
    if [[ ! -f "$service/index.js" ]]; then
        echo "[INFO] Creating minimal index.js in $service"
        cat <<EOF > "$service/index.js"
console.log("Hello from $service");
require('dotenv').config()
EOF
    fi
done

#####################################
# 5) docker-compose.yml
#####################################
COMPOSE_FILE="docker-compose.yml"
if [[ -f "$COMPOSE_FILE" ]]; then
  read -rp "[INFO] docker-compose.yml already exists. Overwrite it? [y/N]: " OVERWRITE
  if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
      echo "[INFO] Overwriting docker-compose.yml..."
        cat <<EOF > "$COMPOSE_FILE"
services:
  mongo:
    image: mongo:latest
    ports:
      - "27017:27017"
  solana_agents:
    build: ./solana_agents
    ports:
      - "5106:3000"
  argus_service:
    build: ./argus_service
    ports:
      - "5101:5000"
  oracle_service:
    build: ./oracle_service
    ports:
      - "5102:5000"
  openai_service:
    build: ./openai_service
    ports:
      - "5103:5000"
  quant_service:
    build: ./quant_service
    ports:
      - "5104:5000"
  ragchain_service:
    build: ./ragchain_service
    ports:
      - "5105:5000"
EOF
   else
        echo "[INFO] Keeping your existing docker-compose.yml, skipping generation."
    fi
else
    echo "[INFO] Creating docker-compose.yml..."
    cat <<EOF > "$COMPOSE_FILE"
services:
  mongo:
    image: mongo:latest
    ports:
      - "27017:27017"
  solana_agents:
    build: ./solana_agents
    ports:
      - "5106:3000"
  argus_service:
    build: ./argus_service
    ports:
      - "5101:5000"
  oracle_service:
    build: ./oracle_service
    ports:
      - "5102:5000"
  openai_service:
    build: ./openai_service
    ports:
      - "5103:5000"
  quant_service:
    build: ./quant_service
    ports:
      - "5104:5000"
  ragchain_service:
    build: ./ragchain_service
    ports:
      - "5105:5000"
EOF
fi

#####################################
# 6) Build and run
#####################################
echo "[INFO] Building images with no cache..."
docker-compose build --no-cache

echo "[INFO] Starting containers in detached mode..."
docker-compose up -d

echo "[SUCCESS] Done! Use 'docker-compose logs -f' to watch logs or 'docker-compose ps' to see containers."
