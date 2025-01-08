#!/usr/bin/env bash
set -e

###############################################################################
# COLORS & LOGGING
###############################################################################
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'
COLOR_NC='\033[0m'

log_info()  { echo -e "${COLOR_GREEN}[INFO] $@${COLOR_NC}"; }
log_warn()  { echo -e "${COLOR_YELLOW}[WARN] $@${COLOR_NC}"; }
log_error() { echo -e "${COLOR_RED}[ERROR] $@${COLOR_NC}"; }

###############################################################################
# STEP 0: CHECK DOCKER & DOCKER COMPOSE
###############################################################################
log_info "Checking Docker engine & docker-compose..."

if ! command -v docker &>/dev/null; then
  log_error "Docker not found. Please install Docker first."
  exit 1
fi

composeCmd=""
if docker compose version &>/dev/null; then
  composeCmd="docker compose"
else
  if command -v docker-compose &>/dev/null; then
    composeCmd="docker-compose"
    log_warn "Using 'docker-compose' instead of 'docker compose'."
  else
    log_error "Neither 'docker compose' nor 'docker-compose' found. Please install Docker Compose."
    exit 1
  fi
fi

log_info "Docker version: $(docker --version)"
if [[ "$composeCmd" == "docker compose" ]]; then
  log_info "Docker Compose plugin version: $(docker compose version || true)"
else
  log_info "Docker Compose version: $($composeCmd version || true)"
fi

###############################################################################
# STEP 1: BUILD IMAGES
#    - We assume you have these folders: ./quant_service,
#      ./ragchain_service, ./solana_agents, each with a Dockerfile
###############################################################################
log_info "Building quant_service_image from ./quant_service..."
docker build -t quant_service_image ./quant_service

log_info "Building ragchain_service_image from ./ragchain_service..."
docker build -t ragchain_service_image ./ragchain_service

log_info "Building solana_agents_image from ./solana_agents..."
docker build -t solana_agents_image ./solana_agents

###############################################################################
# STEP 2: RUN CONTAINERS ON DISTINCT HOST PORTS
#    - We'll remove any old containers named similarly to avoid name conflicts
#    - We'll pick host ports 7002/5002/4002 to avoid collisions
###############################################################################
CONTAINER_Q="quant_service_container_v4"
CONTAINER_R="ragchain_service_container_v4"
CONTAINER_S="solana_agents_container_v4"

log_info "Removing old containers if they exist..."
docker rm -f "$CONTAINER_Q" "$CONTAINER_R" "$CONTAINER_S" &>/dev/null || true

log_info "Running $CONTAINER_Q on host:7002 -> container:7000..."
docker run -d --rm \
  --env-file .env \
  --name "$CONTAINER_Q" \
  -p 7002:7000 \
  quant_service_image

log_info "Running $CONTAINER_R on host:5002 -> container:5000..."
docker run -d --rm \
  --env-file .env \
  --name "$CONTAINER_R" \
  -p 5002:5000 \
  ragchain_service_image

log_info "Running $CONTAINER_S on host:4002 -> container:4000..."
docker run -d --rm \
  --env-file .env \
  --name "$CONTAINER_S" \
  -p 4002:4000 \
  solana_agents_image

###############################################################################
# STEP 3: WAIT FOR /health (MAX 60s)
#    - We'll loop, curl each container's /health route
###############################################################################
log_info "Waiting up to 60 seconds for /health on each container..."

services=(
  "$CONTAINER_Q:7002"
  "$CONTAINER_R:5002"
  "$CONTAINER_S:4002"
)

TIMEOUT=60
START_TIME=$(date +%s)

while true; do
  allHealthy="true"
  for svcport in "${services[@]}"; do
    svc="${svcport%%:*}"
    port="${svcport##*:}"
    code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:${port}/health || true)
    if [[ "$code" != "200" ]]; then
      allHealthy="false"
      break
    fi
  done

  if [[ "$allHealthy" == "true" ]]; then
    log_info "All containers responded 200 to /health."
    break
  fi

  current=$(date +%s)
  elapsed=$(( current - START_TIME ))
  if (( elapsed > TIMEOUT )); then
    log_warn "Timed out waiting for containers' /health. Possibly no /health route or they're still starting."
    break
  fi

  sleep 5
done

###############################################################################
# STEP 4: OPTIONAL: RUN ANY local scripts (e.g., ephemeral chain-of-thought)
###############################################################################
if [[ -f scripts/chain_of_thought.py ]]; then
  log_info "Running ephemeral chain_of_thought.py..."
  python3 scripts/chain_of_thought.py || log_warn "chain_of_thought.py had an error."
else
  log_info "No chain_of_thought.py found, skipping."
fi

if [[ -f scripts/token_management.py ]]; then
  log_info "Running token_management.py..."
  python3 scripts/token_management.py || log_warn "token_management.py had an error."
else
  log_info "No token_management.py found, skipping."
fi

###############################################################################
# STEP 5: SHOW LAST 20 LINES OF CONTAINER LOGS
###############################################################################
log_info "Showing last 20 lines of each container's logs..."
for cname in "$CONTAINER_Q" "$CONTAINER_R" "$CONTAINER_S"; do
  echo "---------------------- [ $cname logs ] ----------------------"
  docker logs --tail 20 "$cname" || true
done

log_info "Done! The containers should be up. Try these URLs (with your droplet IP):"
log_info "http://<YOUR-IP>:7002/health   (quant_service)"
log_info "http://<YOUR-IP>:5002/health   (ragchain_service)"
log_info "http://<YOUR-IP>:4002/health   (solana_agents)"
log_info "master_plan.sh completed successfully!"
