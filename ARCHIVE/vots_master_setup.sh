#!/usr/bin/env bash
set -e

# ==============================================================================
# vots_master_setup.sh
#
# PURPOSE:
#   1) Creates Dockerfiles for solana_agents, ragchain_service, quant_service,
#      ensuring the missing 'flask' is installed for quant_service.
#   2) Creates a docker-compose.yml with health checks & exposed host ports.
#   3) Creates final_extreme_monitor_v4.sh (improved from v3), using host-based
#      port checks, a matrix-like palette, AI summary option, and logs "mistakes"
#      to vots_mistakes.log.
#   4) Finally runs final_extreme_monitor_v4.sh to build images, remove old
#      containers, start them, and monitor everything with advanced logic.
#
#   RUN:
#     sudo ./vots_master_setup.sh
#
#   Press Ctrl+C any time to abort. This is designed to be an "all-in-one"
#   approach for your "VOTS" system ("Visual Orchestrator & Trading System").
#
# PREREQUISITES:
#   - A Debian/Ubuntu-based system with Docker & Docker Compose installed.
#   - Python 3 & openai installed if you want the AI summary, plus:
#       export OPENAI_API_KEY="sk-..."
#
# ==============================================================================

# ------------------------------------------------------------------------------
# 0) Trap Ctrl+C to avoid partial setup
# ------------------------------------------------------------------------------
trap ctrl_c INT
function ctrl_c() {
  echo ""
  echo "[WARN] Caught Ctrl+C. Aborting vots_master_setup.sh."
  exit 1
}

# ------------------------------------------------------------------------------
# 1) Root check
# ------------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Must be run as root (or with sudo). Try: sudo bash vots_master_setup.sh"
  exit 1
fi

# ------------------------------------------------------------------------------
# 2) ASCII Banner (Matrix-like)
# ------------------------------------------------------------------------------
GREEN='\033[38;5;82m'
DARKGREEN='\033[38;5;22m'
RESET='\033[0m'
echo -e "${GREEN} __      ___   ___ _____ "
echo -e " \\ \\    / / | | |_ _|_   _|"
echo -e "  \\ \\/\\/ /| | | || |  | |  "
echo -e "   \\_/\\_/ | |_| || |  | |  "
echo -e "         |_____|___| |_|  ${RESET}"
echo -e "${DARKGREEN}--- VOTS MASTER SETUP ---${RESET}"

# ------------------------------------------------------------------------------
# 3) Creating Dockerfiles
# ------------------------------------------------------------------------------
echo "[INFO] Creating/Overwriting Dockerfiles..."

# solana_agents
mkdir -p solana_agents
cat << 'DOCKER_EOF' > solana_agents/Dockerfile
FROM node:20-alpine
WORKDIR /app

RUN apk update && apk add --no-cache git bash grep sed curl

COPY package.json patch_solana_agent.sh ./
RUN npm install

RUN chmod +x patch_solana_agent.sh && ./patch_solana_agent.sh || echo "No patch needed"

COPY . .

EXPOSE 4000
CMD ["node", "index.js"]
DOCKER_EOF

# ragchain_service
mkdir -p ragchain_service
cat << 'DOCKER_EOF' > ragchain_service/Dockerfile
FROM python:3.10-slim
WORKDIR /app

RUN apt-get update && apt-get install -y build-essential curl git && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000
CMD ["python", "main.py"]
DOCKER_EOF

# quant_service
mkdir -p quant_service
cat << 'DOCKER_EOF' > quant_service/Dockerfile
FROM python:3.10-slim
WORKDIR /app

RUN apt-get update && apt-get install -y build-essential curl && rm -rf /var/lib/apt/lists/*

# Install needed Python libraries, including flask
RUN pip install --no-cache-dir requests fastapi uvicorn flask

COPY . .

EXPOSE 7000
CMD ["python", "main.py"]
DOCKER_EOF

echo "[INFO] Dockerfiles created."

# ------------------------------------------------------------------------------
# 4) Creating minimal code for quant_service if not present
# ------------------------------------------------------------------------------
if [ ! -f quant_service/main.py ]; then
  cat << 'PY_EOF' > quant_service/main.py
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/health")
def health():
    return jsonify({"status": "quant_service OK"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=7000)
PY_EOF
  echo "[INFO] Created a minimal main.py for quant_service (Flask)."
fi

# ------------------------------------------------------------------------------
# 5) Creating docker-compose.yml
# ------------------------------------------------------------------------------
echo "[INFO] Creating/Overwriting docker-compose.yml..."
cat << 'COMPOSE_EOF' > docker-compose.yml
version: '3.8'

services:
  solana_agents:
    build: ./solana_agents
    container_name: solana_agents
    environment:
      - NODE_ENV=production
    ports:
      - "4000:4000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      retries: 3
      start_period: 10s

  ragchain_service:
    build: ./ragchain_service
    container_name: ragchain_service
    environment:
      - PYTHONUNBUFFERED=1
    ports:
      - "5000:5000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      retries: 3
      start_period: 10s

  quant_service:
    build: ./quant_service
    container_name: quant_service
    environment:
      - PYTHONUNBUFFERED=1
    ports:
      - "7000:7000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7000/health"]
      interval: 30s
      retries: 3
      start_period: 10s
COMPOSE_EOF

echo "[INFO] docker-compose.yml created."

# ------------------------------------------------------------------------------
# 6) Creating final_extreme_monitor_v4.sh
#    - Based on final_extreme_monitor_v3 but uses host-based port checks
#    - Logs mistakes to 'vots_mistakes.log'
# ------------------------------------------------------------------------------
echo "[INFO] Creating/Overwriting final_extreme_monitor_v4.sh..."

cat << 'SCRIPT_EOF' > final_extreme_monitor_v4.sh
#!/usr/bin/env bash
set -e

# ==============================================================================
# final_extreme_monitor_v4.sh
#
# Matrix-like advanced script for VOTS. 
#   - Ubuntu update
#   - Docker build & remove old containers
#   - Wait for health
#   - Host-based port checks (no container IP needed)
#   - /health endpoint checks
#   - Analyzes logs for "trade|error|exception|traceback|fail"
#   - Docker stats (CPU/Memory with multi-level thresholds)
#   - Final system usage
#   - Optional AI summary (if python3, openai, and OPENAI_API_KEY are present)
#   - Logs "mistakes" or warnings to vots_mistakes.log
#
# Usage:
#   sudo ./final_extreme_monitor_v4.sh
#   (Press Ctrl+C to abort.)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1) Trap Ctrl+C
# ------------------------------------------------------------------------------
trap ctrl_c INT
function ctrl_c() {
  echo ""
  echo -e "[WARN] Caught Ctrl+C. Aborting final_extreme_monitor_v4.sh."
  exit 1
}

# ------------------------------------------------------------------------------
# 2) Root check
# ------------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Must be run as root (or with sudo)."
  exit 1
fi

# ------------------------------------------------------------------------------
# 3) Matrix Palette & ASCII
# ------------------------------------------------------------------------------
MATRIX_GREEN='\033[38;5;82m'
MATRIX_DARKGREEN='\033[38;5;22m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

vots_mistakes_log="vots_mistakes.log"

info()  { echo -e "${MATRIX_GREEN}[INFO] $*${RESET}"; }
note()  { echo -e "${MATRIX_DARKGREEN}[NOTE] $*${RESET}"; }

warn() {
  echo -e "${YELLOW}[WARN] $*${RESET}"
  echo "$(date) [WARN] $*" >> "$vots_mistakes_log"
}

err() {
  echo -e "${RED}[ERROR] $*${RESET}"
  echo "$(date) [ERROR] $*" >> "$vots_mistakes_log"
  exit 1
}

# ASCII banner
echo -e "${MATRIX_GREEN} __      ___   ___ _____ "
echo -e " \\ \\    / / | | |_ _|_   _|"
echo -e "  \\ \\/\\/ /| | | || |  | |  "
echo -e "   \\_/\\_/ | |_| || |  | |  "
echo -e "         |_____|___| |_|  ${RESET}"
echo -e "${MATRIX_DARKGREEN}--- final_extreme_monitor_v4.sh (VOTS) ---${RESET}"

# ------------------------------------------------------------------------------
# 4) Config
# ------------------------------------------------------------------------------
SERVICES=(solana_agents ragchain_service quant_service)
declare -A SERVICE_PORTS=(["solana_agents"]="4000" ["ragchain_service"]="5000" ["quant_service"]="7000")

MAX_WAIT_HEALTH=90
LOG_TAIL_LINES=100
LOG_KEYWORDS=("trade" "error" "exception" "traceback" "fail")
MEMORY_WARN_THRESHOLD=80
MEMORY_CRITICAL_THRESHOLD=90
CPU_WARN_THRESHOLD=70
CPU_CRITICAL_THRESHOLD=90

# ------------------------------------------------------------------------------
# 5) AI Summary Helper
# ------------------------------------------------------------------------------
function ai_summary() {
  # Accept logs as $1
  local logs_content="$1"

  # Check python, openai lib, env var
  if ! command -v python3 &>/dev/null; then
    warn "Python 3 not found, skipping AI summary."
    return
  fi
  python3 -c "import openai" &>/dev/null || {
    warn "Python 'openai' not installed. pip install openai"
    return
  }
  if [ -z "$OPENAI_API_KEY" ]; then
    warn "OPENAI_API_KEY not set, skipping AI summary."
    return
  fi

  local tmpfile="/tmp/ai_prompt_$$.txt"
  cat > "$tmpfile" <<EOM
You are a helpful assistant analyzing logs from a Solana-based quant trading system called VOTS.
Here's the recent log excerpt (across multiple containers). Summarize key trades, errors, or anomalies,
and provide recommended next steps. Mark any critical mistakes:

======== LOGS BEGIN ========
$logs_content
======== LOGS END ========
EOM

  note "Requesting AI summary from OpenAI..."

  python3 <<PYCODE
import os
import openai

openai.api_key = os.environ.get("OPENAI_API_KEY", "")

with open("$tmpfile", "r") as f:
    prompt = f.read()

    model="text-davinci-003",
    prompt=prompt,
    temperature=0.2,
    max_tokens=500
)

print("${MATRIX_GREEN}--- AI Summary ---${RESET}")
print(resp.choices[0].text.strip())
print("${MATRIX_GREEN}--- End of AI Summary ---${RESET}")
PYCODE

  rm -f "$tmpfile"
}

# ------------------------------------------------------------------------------
# 6) System Update
# ------------------------------------------------------------------------------
info "Updating & upgrading the Ubuntu system..."
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y
apt-get autoclean -y

[ -f /var/run/reboot-required ] && warn "A system reboot is required after this script!"

# ------------------------------------------------------------------------------
# 7) Remove old containers
# ------------------------------------------------------------------------------
info "Removing old containers for: ${SERVICES[*]} etc..."
docker ps -a | grep -E 'solana_agents|ragchain_service|quant_service|dexscrender|jupiter|raydium' \
  | awk '{print $1}' | xargs -r docker rm -f || true

# ------------------------------------------------------------------------------
# 8) Docker Compose Build & Up
# ------------------------------------------------------------------------------
info "Building Docker images with --no-cache..."
docker-compose build --no-cache || err "docker-compose build failed!"

info "Starting containers in detached mode..."
docker-compose up -d || err "docker-compose up failed!"

# ------------------------------------------------------------------------------
# 9) Wait for Docker Health
# ------------------------------------------------------------------------------
info "Waiting up to $MAX_WAIT_HEALTH seconds for Docker services to become healthy..."
start_time=$(date +%s)
while true; do
  all_healthy=true
  for svc in "${SERVICES[@]}"; do
    cid=$(docker-compose ps -q "$svc" || true)
    if [ -z "$cid" ]; then
      warn "No container found for service: $svc"
      all_healthy=false
      continue
    fi
    status=$(docker inspect --format='{{.State.Health.Status}}' "$cid" 2>/dev/null || echo 'missing')
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
  if [ $elapsed -ge $MAX_WAIT_HEALTH ]; then
    warn "Not all containers became healthy within $MAX_WAIT_HEALTH seconds."
    break
  fi
  sleep 5
done

# ------------------------------------------------------------------------------
# 10) Host-based Port Checks
# ------------------------------------------------------------------------------
note "Performing container port checks (host-based) with 'nc -z localhost'..."
for svc in "${SERVICES[@]}"; do
  host_port="${SERVICE_PORTS[$svc]}"
  if ! nc -z localhost "$host_port"; then
    warn "$svc is 'healthy' but localhost:$host_port not open"
  else
    info "$svc => host port $host_port is open"
  fi
done

# ------------------------------------------------------------------------------
# 11) Specific Endpoint Checks (/health)
# ------------------------------------------------------------------------------
note "Checking /health endpoints on localhost..."
for svc in "${SERVICES[@]}"; do
  host_port="${SERVICE_PORTS[$svc]}"
  if ! curl -sf "http://localhost:$host_port/health" >/dev/null; then
    warn "$svc => /health check failed on localhost:$host_port"
  else
    info "$svc => /health responded OK on localhost:$host_port"
  fi
done

# ------------------------------------------------------------------------------
# 12) Logs Analysis
# ------------------------------------------------------------------------------
info "Analyzing last $LOG_TAIL_LINES lines of logs for keywords: ${LOG_KEYWORDS[*]}"
declare -A CONTAINER_LOG_SUMMARY
ALL_LOGS=""

for svc in "${SERVICES[@]}"; do
  cid=$(docker-compose ps -q "$svc" || true)
  if [ -z "$cid" ]; then
    warn "No container for $svc, skipping logs."
    continue
  fi

  note "===== $svc logs (tail $LOG_TAIL_LINES) ====="
  recent_logs=$(docker logs --tail="$LOG_TAIL_LINES" "$cid" 2>&1 || true)
  echo "$recent_logs"
  echo ""

  ALL_LOGS="$ALL_LOGS
===== Service: $svc =====
$recent_logs
"

  CONTAINER_LOG_SUMMARY["$svc"]=""
  for term in "${LOG_KEYWORDS[@]}"; do
    count=$(echo "$recent_logs" | grep -i "$term" | wc -l)
    if [ "$count" -gt 0 ]; then
      summary="${CONTAINER_LOG_SUMMARY["$svc"]} $term:$count"
      CONTAINER_LOG_SUMMARY["$svc"]="$summary"
    fi
  done
done

# ------------------------------------------------------------------------------
# 13) Docker Stats
# ------------------------------------------------------------------------------
info "Checking container CPU/Memory usage with docker stats --no-stream..."
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" \
| while read line; do

  if echo "$line" | grep -q "MEM USAGE"; then
    echo -e "${MATRIX_DARKGREEN}$line${RESET}"
    continue
  fi

  cpu_raw=$(echo "$line" | awk '{print $2}' | sed 's/%//')
  mem_raw=$(echo "$line" | awk '{print $4}' | sed 's/%//')
  if [[ "$cpu_raw" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    cpu_int=$(printf "%.0f" "$cpu_raw")
  else
    cpu_int=0
  fi
  if [[ "$mem_raw" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    mem_int=$(printf "%.0f" "$mem_raw")
  else
    mem_int=0
  fi

  # CPU thresholds
  cpu_msg=""
  if [ "$cpu_int" -gt "$CPU_CRITICAL_THRESHOLD" ]; then
    cpu_msg="${RED}(CPU > ${CPU_CRITICAL_THRESHOLD}% - CRITICAL)${RESET}"
    echo -e "${RED}$line $cpu_msg${RESET}"
    echo "$(date) [ERROR] $line CPU critical" >> vots_mistakes.log
  elif [ "$cpu_int" -gt "$CPU_WARN_THRESHOLD" ]; then
    cpu_msg="${YELLOW}(CPU > ${CPU_WARN_THRESHOLD}% - WARN)${RESET}"
    echo -e "${YELLOW}$line $cpu_msg${RESET}"
    echo "$(date) [WARN] $line CPU warn" >> vots_mistakes.log
  else
    cpu_msg=""
  fi

  # Memory thresholds
  mem_msg=""
  if [ "$mem_int" -gt "$MEMORY_CRITICAL_THRESHOLD" ]; then
    mem_msg="${RED}(MEM > ${MEMORY_CRITICAL_THRESHOLD}% - CRITICAL)${RESET}"
    echo -e "${RED}$line $mem_msg${RESET}"
    echo "$(date) [ERROR] $line Memory critical" >> vots_mistakes.log
  elif [ "$mem_int" -gt "$MEMORY_WARN_THRESHOLD" ]; then
    mem_msg="${YELLOW}(MEM > ${MEMORY_WARN_THRESHOLD}% - WARN)${RESET}"
    echo -e "${YELLOW}$line $mem_msg${RESET}"
    echo "$(date) [WARN] $line Memory warn" >> vots_mistakes.log
  else
    if [ -z "$cpu_msg" ]; then
      echo -e "${MATRIX_GREEN}$line${RESET}"
    fi
  fi
done

# ------------------------------------------------------------------------------
# 14) Final System Usage
# ------------------------------------------------------------------------------
info "Final system resource usage..."

LOAD_AVG=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
info "CPU Load (1/5/15): $LOAD_AVG"

mem_usage=$(free -m | awk '/Mem:/{printf "%dMB used / %dMB total (%.1f%%)", $3, $2, $3*100/$2}')
info "Memory Usage: $mem_usage"

swap_line=$(free -m | awk '/Swap:/')
swap_total=$(echo "$swap_line" | awk '{print $2}')
swap_used=$(echo "$swap_line" | awk '{print $3}')
if [ "$swap_total" -eq 0 ]; then
  info "Swap Usage: 0MB used / 0MB total (0%)"
else
  swap_pct=$(awk -v used="$swap_used" -v total="$swap_total" 'BEGIN {printf "%.1f", used*100/total}')
  info "Swap Usage: ${swap_used}MB used / ${swap_total}MB total (${swap_pct}%)"
fi

disk_usage=$(df -h / | awk 'NR==2{print $5 " used on /"}')
info "Disk Usage on /: $disk_usage"

info "Log keyword summary (last $LOG_TAIL_LINES lines/container):"
for svc in "${SERVICES[@]}"; do
  summary="${CONTAINER_LOG_SUMMARY["$svc"]}"
  if [ -n "$summary" ]; then
    echo "   $svc => $summary"
  else
    echo "   $svc => no ${LOG_KEYWORDS[*]} found"
  fi
done

# ------------------------------------------------------------------------------
# 15) Optional AI Summary
# ------------------------------------------------------------------------------
ai_summary "$ALL_LOGS"

note "final_extreme_monitor_v4.sh complete! Check vots_mistakes.log for warnings/errors."
SCRIPT_EOF

chmod +x final_extreme_monitor_v4.sh
echo "[INFO] final_extreme_monitor_v4.sh created."

# ------------------------------------------------------------------------------
# 7) Finally, run final_extreme_monitor_v4.sh
# ------------------------------------------------------------------------------
echo "[INFO] Now running final_extreme_monitor_v4.sh..."
./final_extreme_monitor_v4.sh || true

echo "[INFO] vots_master_setup.sh complete!"
