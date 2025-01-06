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
  # Example of retrieving the latest ephemeral thought and summarizing it
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
