#!/usr/bin/env bash
#
# final_master_setup.sh
#
# Purpose:
#   - Check Docker & Docker Compose
#   - Optionally prune Docker
#   - Ensure python -> python3
#   - Keep or create .env
#   - Create subfolders & minimal Dockerfiles if missing
#   - Create minimal 'setup.py' or 'package.json' if missing
#   - Optionally overwrite docker-compose.yml
#   - docker-compose up --build -d
#
# Usage:
#   chmod +x final_master_setup.sh
#   ./final_master_setup.sh
#
# Requirements:
#   - Docker & docker-compose installed
#   - (Ubuntu/Debian) for the 'python-is-python3' step
#   - This script placed in your project root (e.g. ~/qmcs).
#
#   **Remember**: You likely need more robust Dockerfiles in practice,
#   plus real 'setup.py' or 'package.json'. These are minimal stubs.

set -e  # Exit immediately on error

########################################
# 1) Check for Docker & Docker Compose
########################################
echo "[INFO] Checking Docker..."
if ! command -v docker &> /dev/null; then
  echo "[ERROR] Docker not found. Please install Docker first."
  exit 1
fi

echo "[INFO] Checking Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
  echo "[ERROR] docker-compose not found. Please install docker-compose."
  exit 1
fi

########################################
# 2) Optional Docker prune
########################################
read -rp "[INFO] Prune old Docker resources first? [y/N]: " PRUNE_CHOICE
if [[ "$PRUNE_CHOICE" =~ ^[Yy]$ ]]; then
  echo "[INFO] Attempting Docker system prune..."
  # 'docker-compose down' ensures no leftover containers from old
  docker-compose down || true
  docker system prune -af --volumes || true
fi

########################################
# 3) Ensure python -> python3 (Ubuntu/Debian)
########################################
if ! command -v python &>/dev/null; then
  echo "[INFO] 'python' not found. Installing python-is-python3 (Ubuntu/Debian) ..."
  sudo apt-get update -y && sudo apt-get install -y python-is-python3
else
  echo "[INFO] 'python' command is available."
fi

########################################
# 4) Check for .env
########################################
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
  echo "[INFO] Found existing .env; leaving it as is."
else
  echo "[INFO] No .env found. Creating a minimal example .env..."
  cat <<EOF > "$ENV_FILE"
# Example .env
# Place your environment variables here
SAMPLE_ENV_VAR="hello"
EOF
fi

########################################
# Helper functions for minimal Dockerfiles
########################################
create_minimal_python_dockerfile() {
  local dir="$1"
  cat <<'EODF' > "${dir}/Dockerfile"
FROM python:3.10-slim

WORKDIR /app
COPY . /app

# For an actual project: either install from requirements.txt or from setup.py
# If you have a requirements.txt:
#   RUN pip install --no-cache-dir -r requirements.txt
# If you have a setup.py:
RUN pip install --no-cache-dir .

CMD ["python", "main.py"]  # Or adjust as needed
EODF
}

create_minimal_node_dockerfile() {
  local dir="$1"
  cat <<'EODF' > "${dir}/Dockerfile"
FROM node:18-slim

WORKDIR /app
COPY package.json /app

RUN npm install
COPY . /app

CMD ["npm", "start"]  # Or adjust as needed
EODF
}

create_minimal_unknown_dockerfile() {
  local dir="$1"
  cat <<EODF > "${dir}/Dockerfile"
# Minimal Dockerfile placeholder for $dir
FROM alpine:3.18
RUN echo "Hello from $dir" > /hello.txt
CMD ["cat", "/hello.txt"]
EODF
}

########################################
# Helper functions for minimal setup.py or package.json
########################################
create_minimal_setup_py() {
  local dir="$1"
  cat <<'EOSPY' > "${dir}/setup.py"
from setuptools import setup, find_packages

setup(
    name="my_package",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[],  # Add your actual dependencies here
)
EOSPY
}

create_minimal_package_json() {
  local dir="$1"
  cat <<'EOPKG' > "${dir}/package.json"
{
  "name": "solana-agents",
  "version": "1.0.0",
  "description": "Minimal Node app placeholder",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "axios": "^1.0.0"
  }
}
EOPKG
}

########################################
# 5) Create subfolders & minimal Dockerfiles if missing
########################################
declare -a SERVICE_DIRS=(
  "openai_service"
  "solana_agents"
  "quant_service"
  "ragchain_service"
  "oracle_service"
  "argus_service"
)

for service_dir in "${SERVICE_DIRS[@]}"; do
  if [ ! -d "$service_dir" ]; then
    echo "[INFO] Creating missing folder: $service_dir"
    mkdir -p "$service_dir"
  fi

  # Dockerfile
  if [ ! -f "${service_dir}/Dockerfile" ]; then
    echo "[INFO] Creating a minimal Dockerfile in $service_dir"
    case "$service_dir" in
      # Node-based example
      "solana_agents")
        create_minimal_node_dockerfile "$service_dir"
        [ ! -f "${service_dir}/package.json" ] && create_minimal_package_json "$service_dir"
        ;;
      # Python-based examples
      "openai_service"|"quant_service"|"ragchain_service"|"oracle_service"|"argus_service")
        create_minimal_python_dockerfile "$service_dir"
        # If there's no setup.py, create a minimal one
        [ ! -f "${service_dir}/setup.py" ] && create_minimal_setup_py "$service_dir"
        ;;
      # Otherwise, just create a trivial Dockerfile
      *)
        create_minimal_unknown_dockerfile "$service_dir"
        ;;
    esac
  fi
done

########################################
# 6) Generate or keep docker-compose.yml
########################################
COMPOSE_FILE="docker-compose.yml"
if [ -f "$COMPOSE_FILE" ]; then
  echo "[INFO] $COMPOSE_FILE already exists."
  read -rp "[INFO] Overwrite it? [y/N]: " OVERWRITE_CHOICE
  if [[ "$OVERWRITE_CHOICE" =~ ^[Yy]$ ]]; then
    echo "[INFO] Overwriting docker-compose.yml..."
  else
    echo "[INFO] Keeping your existing $COMPOSE_FILE, skipping generation."
    echo "[INFO] Building images (no cache) & starting containers in detached mode..."
    docker-compose build --no-cache
    docker-compose up -d
    echo "[SUCCESS] Done! Run 'docker-compose logs -f' or 'docker ps' to confirm containers."
    exit 0
  fi
fi

# If we reached here, either docker-compose.yml didn't exist or we chose to overwrite.
cat <<'EOF_DC' > "$COMPOSE_FILE"
###################################################################
# Minimal Docker Compose Example
###################################################################
# (Remove 'version' or put the correct spec if you want to suppress the warning)
version: "3.9"

services:
  mongo:
    image: mongo:latest
    container_name: local_mongo
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db

  openai_service:
    build:
      context: ./openai_service
    container_name: openai_service
    depends_on:
      - mongo
    ports:
      - "3001:3001"
    networks:
      - sol-ai-net

  solana_agents:
    build:
      context: ./solana_agents
    container_name: solana_agents
    ports:
      - "4000:4000"
    networks:
      - sol-ai-net

  quant_service:
    build:
      context: ./quant_service
    container_name: quant_service
    ports:
      - "7000:7000"
    networks:
      - sol-ai-net

  ragchain_service:
    build:
      context: ./ragchain_service
    container_name: ragchain_service
    ports:
      - "5000:5000"
    depends_on:
      - mongo
    networks:
      - sol-ai-net

  oracle_service:
    build:
      context: ./oracle_service
    container_name: oracle_service
    ports:
      - "6000:6000"
    networks:
      - sol-ai-net

  argus_service:
    build:
      context: ./argus_service
    container_name: argus_service
    ports:
      - "8000:8000"
    networks:
      - sol-ai-net

volumes:
  mongo_data:

networks:
  sol-ai-net:
    name: sol-ai-network
EOF_DC

echo "[INFO] Building images (no cache) & starting containers in detached mode..."
docker-compose build --no-cache
docker-compose up -d

echo "[SUCCESS] Done! Run 'docker-compose logs -f' or 'docker ps' to monitor."
exit 0
