#!/usr/bin/env bash
set -e

###############################################################################
# cat_all_architecture.sh
#
# Helper script that displays (cat) each key file in your multi-service
# Docker-based project. It helps you quickly review the entire architecture
# (Dockerfiles, docker-compose.yml, code in solana_agents, ragchain_service,
# quant_service, browser_service, knowledge_service, utils, final_extreme_monitor_v4.sh, etc.)
#
# Usage:
#   chmod +x cat_all_architecture.sh
#   ./cat_all_architecture.sh
###############################################################################

echo "[INFO] ============ Dockerfiles ============"
echo ""
echo "[INFO] --- Dockerfile (root, if any) ---"
[ -f Dockerfile ] && cat Dockerfile || echo "[WARN] Dockerfile not found at project root."
echo ""

echo "[INFO] --- docker-compose.yml ---"
[ -f docker-compose.yml ] && cat docker-compose.yml || echo "[WARN] docker-compose.yml not found."
echo ""

echo "[INFO] --- solana_agents/Dockerfile ---"
[ -f solana_agents/Dockerfile ] && cat solana_agents/Dockerfile || echo "[WARN] solana_agents/Dockerfile not found."
echo ""

echo "[INFO] --- ragchain_service/Dockerfile ---"
[ -f ragchain_service/Dockerfile ] && cat ragchain_service/Dockerfile || echo "[WARN] ragchain_service/Dockerfile not found."
echo ""

echo "[INFO] --- quant_service/Dockerfile ---"
[ -f quant_service/Dockerfile ] && cat quant_service/Dockerfile || echo "[WARN] quant_service/Dockerfile not found."
echo ""

echo "[INFO] --- browser_service/Dockerfile ---"
[ -f browser_service/Dockerfile ] && cat browser_service/Dockerfile || echo "[WARN] browser_service/Dockerfile not found."
echo ""

echo "[INFO] --- knowledge_service/Dockerfile ---"
[ -f knowledge_service/Dockerfile ] && cat knowledge_service/Dockerfile || echo "[WARN] knowledge_service/Dockerfile not found."
echo ""

echo "[INFO] ============ Service Code ============"
echo ""
echo "[INFO] --- solana_agents code ---"
if [ -d solana_agents ]; then
  find solana_agents -type f -name "*.js" -o -name "*.json" -o -name "*.sh" -o -name "*.ts" | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] solana_agents dir not found."
fi
echo ""

echo "[INFO] --- ragchain_service code ---"
if [ -d ragchain_service ]; then
  find ragchain_service -type f -name "*.py" -o -name "*.sh" | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] ragchain_service dir not found."
fi
echo ""

echo "[INFO] --- quant_service code ---"
if [ -d quant_service ]; then
  find quant_service -type f -name "*.py" -o -name "*.sh" | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] quant_service dir not found."
fi
echo ""

echo "[INFO] --- browser_service code ---"
if [ -d browser_service ]; then
  find browser_service -type f -name "*.py" -o -name "*.sh" | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] browser_service dir not found."
fi
echo ""

echo "[INFO] --- knowledge_service code ---"
if [ -d knowledge_service ]; then
  find knowledge_service -type f -name "*.py" -o -name "*.sh" | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] knowledge_service dir not found."
fi
echo ""

echo "[INFO] --- utils code ---"
if [ -d utils ]; then
  find utils -type f -name "*.py" -o -name "*.sh" | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] utils dir not found."
fi
echo ""

echo "[INFO] ============ final_extreme_monitor_v4.sh ============"
[ -f final_extreme_monitor_v4.sh ] && cat final_extreme_monitor_v4.sh || echo "[WARN] final_extreme_monitor_v4.sh not found."
echo ""

echo "[INFO] ============ End of cat_all_architecture.sh ============"
