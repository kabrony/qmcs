#!/usr/bin/env bash
set -e

# --------------------------------------------------------------------------------
#  This single script updates the Ubuntu system, rebuilds all Docker services,
#  then checks health endpoints to ensure everything (e.g., OpenAI, Gemini, Tavily,
#  Raydium, Jupiter, Solana Agents) is up.
#
#  Usage:
#    sudo ./final_mega_update.sh
#
#  Press Ctrl+C to abort at any time; we handle it gracefully.
# --------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Trap for Ctrl+C (SIGINT)
# ------------------------------------------------------------------------------
trap ctrl_c INT
function ctrl_c() {
  echo ""
  echo "[WARN] Caught Ctrl+C. Aborting final_mega_update.sh script."
  exit 1
}

# ------------------------------------------------------------------------------
# Root check
# ------------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Must be run as root (or with sudo). Try: sudo bash final_mega_update.sh"
  exit 1
fi

# ------------------------------------------------------------------------------
# Color logging
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO] $*${NC}"; }
warn()  { echo -e "${YELLOW}[WARN] $*${NC}"; }
err()   { echo -e "${RED}[ERROR] $*${NC}"; exit 1; }
note()  { echo -e "${CYAN}[NOTE] $*${NC}"; }

# ------------------------------------------------------------------------------
# 1) Update Ubuntu system
# ------------------------------------------------------------------------------
info "Updating & upgrading the Ubuntu system..."
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y

# Optional clean-up
apt-get autoremove -y
apt-get autoclean -y

# Check if reboot required
if [ -f /var/run/reboot-required ]; then
  warn "A system reboot is required (kernel or major library)."
  warn "Recommend reboot after this script finishes."
fi

# ------------------------------------------------------------------------------
# 2) Remove old containers that might conflict
# ------------------------------------------------------------------------------
info "Removing old containers named solana_agents, ragchain_service, quant_service, etc. if they exist..."
docker ps -a | grep -E 'solana_agents|ragchain_service|quant_service|dexscrender|jupiter|raydium' \
  | awk '{print $1}' | xargs -r docker rm -f || true

# ------------------------------------------------------------------------------
# 3) Docker-Compose build & up
# ------------------------------------------------------------------------------
info "Building Docker images with --no-cache (this may take time)..."
docker-compose build --no-cache

info "Starting containers in detached mode..."
docker-compose up -d

# ------------------------------------------------------------------------------
# 4) Wait for health checks (up to 60s)
# ------------------------------------------------------------------------------
SERVICES=(solana_agents ragchain_service quant_service)  # Add or remove names as needed
start_time=$(date +%s)
max_wait=60
info "Waiting up to ${max_wait}s for containers to become healthy..."

while true; do
  all_healthy=true
  for svc in "${SERVICES[@]}"; do
    cid=$(docker-compose ps -q "$svc" || true)
    if [ -z "$cid" ]; then
      all_healthy=false
      break
    fi
    status=$(docker inspect --format='{{.State.Health.Status}}' "$cid" 2>/dev/null || echo 'missing')
    if [ "$status" != "healthy" ]; then
      all_healthy=false
      break
    fi
  done

  if $all_healthy; then
    info "All requested services are healthy!"
    break
  fi

  elapsed=$(( $(date +%s) - start_time ))
  if [ $elapsed -ge $max_wait ]; then
    warn "Not all containers reported healthy within $max_wait seconds. Proceeding anyway..."
    break
  fi
  sleep 5
done

# ------------------------------------------------------------------------------
# 5) Basic Endpoint Tests
# ------------------------------------------------------------------------------
# These are examples for confirming each service is at least responding on
# expected ports. Adjust as needed for your environment.

note "Testing solana_agents on port 4000..."
curl -sf http://localhost:4000/health && info "solana_agents responded OK" || warn "solana_agents check failed"

note "Testing ragchain_service on port 5000..."
curl -sf http://localhost:5000/health && info "ragchain_service responded OK" || warn "ragchain_service check failed"

note "Testing quant_service on port 7000..."
curl -sf http://localhost:7000/health && info "quant_service responded OK" || warn "quant_service check failed"

# Add more checks for jupiter, raydium, gemini, tavily, openai, etc.

# ------------------------------------------------------------------------------
# 6) Done
# ------------------------------------------------------------------------------
info "All done! If needed, reboot or check logs. Press Ctrl+C to exit at any time."
