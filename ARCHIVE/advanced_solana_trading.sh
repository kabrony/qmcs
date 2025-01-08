#!/usr/bin/env bash
set -e

# ANSI logs
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO] $*${NC}"; }
warn()  { echo -e "${YELLOW}[WARN] $*${NC}"; }
error() { echo -e "${RED}[ERROR] $*${NC}"; exit 1; }

# 0) Check .env
info "Checking .env..."
if [[ ! -f .env ]]; then
  error ".env not found."
fi

# 1) Build containers with docker-compose
info "Building containers with 'docker-compose build'..."
docker-compose build --no-cache

# 2) Up them in detached mode
info "Starting containers with 'docker-compose up -d'..."
docker-compose up -d

# 3) Wait for them to be healthy
info "Waiting up to 60s for containers: solana_agents, ragchain_service, quant_service..."
start_time=$(date +%s)
max_wait=60
while true; do
  all_healthy=true
  for svc in solana_agents ragchain_service quant_service; do
    status="$(docker inspect --format='{{.State.Health.Status}}' $(docker-compose ps -q $svc) 2>/dev/null || echo 'missing')"
    if [[ "$status" != "healthy" ]]; then
      all_healthy=false
      break
    fi
  done

  if $all_healthy; then
    info "All services are healthy!"
    break
  fi

  now=$(date +%s)
  if (( now - start_time > max_wait )); then
    warn "Not all services became healthy within 60s..."
    break
  fi

  sleep 5
done

# 4) Fake advanced logic: call each service
info "Checking endpoints..."

# solana_agents at host:4002
curl -s http://localhost:4002/health || warn "solana_agents /health failed"
balance_json="$(curl -s http://localhost:4002/balance || true)"
echo "[solana_agents] /balance => $balance_json"

# ragchain_service at host:5002
curl -s http://localhost:5002/health || warn "ragchain_service /health failed"
dec_json="$(curl -s -X POST http://localhost:5002/decision -H 'Content-Type: application/json' -d '{"current_balance":1.23}')"
echo "[ragchain_service] /decision => $dec_json"

# quant_service at host:7002
curl -s http://localhost:7002/health || warn "quant_service /health failed"
trade_json="$(curl -s -X POST http://localhost:7002/trade -H 'Content-Type: application/json' -d '{"amount":0.05}')"
echo "[quant_service] /trade => $trade_json"

info "All done. Check logs via 'docker-compose logs -f' if needed."
