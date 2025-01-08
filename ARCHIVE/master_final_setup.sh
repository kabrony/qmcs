kkk#!/usr/bin/env bash
#
# master_system_setup.sh
#
# Purpose:
#   1) Optionally prune Docker resources (skip with: SKIP_DOCKER_PRUNE="yes" ./master_system_setup.sh).
#   2) Ensure .env (don’t overwrite existing).
#   3) Generate or update docker-compose.yml referencing .env.
#   4) Attempt to install system dependencies needed (like python-is-python3).
#   5) Build & run your containers in detached mode.
#
# Usage:
#   chmod +x master_system_setup.sh
#   ./master_system_setup.sh
# or skip Docker prune:
#   SKIP_DOCKER_PRUNE="yes" ./master_system_setup.sh

set -Eeuo pipefail

# ------------------------------------------------------------------------------
# 0) Optionally prune Docker
# ------------------------------------------------------------------------------
if [ "${SKIP_DOCKER_PRUNE:-}" != "yes" ]; then
  echo "[INFO] Attempting Docker prune..."
  docker-compose down --remove-orphans || true
  docker system prune -af --volumes
else
  echo "[INFO] Skipping Docker prune."
fi

# ------------------------------------------------------------------------------
# 1) Install system dependencies (e.g. python-is-python3) - optional
# ------------------------------------------------------------------------------
# If you want the `python` command to refer to Python 3:
if ! command -v python >/dev/null 2>&1; then
  echo "[INFO] 'python' not found. Installing python-is-python3 (Ubuntu/Debian) ..."
  sudo apt-get update -y && sudo apt-get install -y python-is-python3
else
  echo "[INFO] 'python' command is available."
fi

# ------------------------------------------------------------------------------
# 2) Ensure .env file (create stub if none)
# ------------------------------------------------------------------------------
if [ -f .env ]; then
  echo "[INFO] Found existing .env; leaving it as is."
else
  echo "[INFO] Creating a minimal .env stub. Please edit with real secrets."
  cat <<'ENVFILE' > .env
# ============================
# Example .env (EDIT THIS!!!)
# ============================
MONGO_DETAILS="mongodb://localhost:27017"
OPENAI_API_KEY="sk-your-openai-key"
GEMINI_API_KEY="AIzaSyCo..."
# ... add more as needed

# (Optional) MySQL examples
# MYSQL_DATABASE=rag_flow
# MYSQL_USER=ragflowuser
# MYSQL_PASSWORD=ragflow123
# MYSQL_ROOT_PASSWORD=mysecretpassword
ENVFILE
fi

# ------------------------------------------------------------------------------
# 3) Generate/Update docker-compose.yml
# ------------------------------------------------------------------------------
echo "[INFO] Generating docker-compose.yml..."

cat <<'COMPOSEYML' > docker-compose.yml
version: "3.9"

services:
  # Example: MONGO
  mongo:
    image: mongo:latest
    restart: always
    env_file:
      - .env
    # ports, volumes, etc.
    ports:
      - "27017:27017"
    networks:
      - mainnet

  # Argus or other Tool Example:
  # If you have a Dockerfile in ./Argus
  argus_service:
    build:
      context: ./Argus
      dockerfile: Dockerfile
    # If you have a ready-made image, replace with "image: your-registry/argus:latest"
    env_file:
      - .env
    restart: always
    networks:
      - mainnet
    # If Argus is a CLI, you might not need an exposed port. If you do, e.g.:
    # ports:
    #   - "8000:8000"

  # More services (ragchain_service, quant_service, openai_service, solana_agents)
  ragchain_service:
    build:
      context: ./ragchain_service
      dockerfile: Dockerfile
    env_file:
      - .env
    restart: always
    networks:
      - mainnet
    ports:
      - "5000:5000"

  quant_service:
    build:
      context: ./quant_service
      dockerfile: Dockerfile
    env_file:
      - .env
    restart: always
    networks:
      - mainnet
    ports:
      - "7000:7000"

  openai_service:
    build:
      context: ./openai_service
      dockerfile: Dockerfile
    env_file:
      - .env
    restart: always
    networks:
      - mainnet
    ports:
      - "3001:3001"

  solana_agents:
    build:
      context: ./solana_agents
      dockerfile: Dockerfile
    env_file:
      - .env
    restart: always
    networks:
      - mainnet
    ports:
      - "4000:4000"

#  # Possibly MySQL
#  mysql:
#    image: mysql:8
#    env_file:
#      - .env
#    # environment:
#    #   MYSQL_DATABASE: ${MYSQL_DATABASE}
#    #   MYSQL_USER: ${MYSQL_USER}
#    #   MYSQL_PASSWORD: ${MYSQL_PASSWORD}
#    #   MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
#    restart: always
#    networks:
#      - mainnet
#    ports:
#      - "3306:3306"

#  # Possibly Redis
#  redis:
#    image: redis:7
#    command: ["redis-server", "--requirepass", "${REDIS_PASSWORD}"]
#    env_file:
#      - .env
#    restart: always
#    networks:
#      - mainnet
#    ports:
#      - "6379:6379"

networks:
  mainnet:
    name: mainnet
COMPOSEYML

# ------------------------------------------------------------------------------
# 4) Docker Compose Build & Up
# ------------------------------------------------------------------------------
echo "[INFO] Building images (no cache)..."
docker-compose build --no-cache

echo "[INFO] Starting containers in detached mode..."
docker-compose up -d

echo "[SUCCESS] Done! Check logs with: docker-compose logs -f"
echo "[INFO] Use 'docker-compose ps' to see container states."

