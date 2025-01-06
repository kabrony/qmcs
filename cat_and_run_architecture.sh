#!/usr/bin/env bash
set -e

###############################################################################
# cat_and_run_architecture.sh
#
# 1) Displays (cats) the Dockerfiles, docker-compose.yml, plus code in
#    solana_agents, ragchain_service, quant_service, etc.
# 2) Then suggests how to build & run them using docker-compose.
#
# Usage:
#   chmod +x cat_and_run_architecture.sh
#   ./cat_and_run_architecture.sh
#
# On success, you'll see all key files printed out, then instructions to:
#   docker-compose build
#   docker-compose up -d
#   ./final_extreme_monitor_v4.sh
###############################################################################

echo "[INFO] ============ Dockerfiles ============"
echo ""
echo "[INFO] --- Dockerfile (root, if any) ---"
[ -f Dockerfile ] && cat Dockerfile || echo "[WARN] No root-level Dockerfile found."
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

###############################################################################
echo "[INFO] ============ Service Code ============"
echo ""
###############################################################################
echo "[INFO] --- solana_agents code ---"
if [ -d solana_agents ]; then
  find solana_agents -type f \( -name "*.js" -o -name "*.json" -o -name "*.sh" -o -name "*.ts" \) | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] solana_agents/ not found."
fi
echo ""

echo "[INFO] --- ragchain_service code ---"
if [ -d ragchain_service ]; then
  find ragchain_service -type f \( -name "*.py" -o -name "*.sh" \) | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] ragchain_service/ not found."
fi
echo ""

echo "[INFO] --- quant_service code ---"
if [ -d quant_service ]; then
  find quant_service -type f \( -name "*.py" -o -name "*.sh" \) | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] quant_service/ not found."
fi
echo ""

echo "[INFO] --- browser_service code ---"
if [ -d browser_service ]; then
  find browser_service -type f \( -name "*.py" -o -name "*.sh" \) | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] browser_service/ not found."
fi
echo ""

echo "[INFO] --- knowledge_service code ---"
if [ -d knowledge_service ]; then
  find knowledge_service -type f \( -name "*.py" -o -name "*.sh" \) | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] knowledge_service/ not found."
fi
echo ""

###############################################################################
echo "[INFO] --- utils code ---"
if [ -d utils ]; then
  find utils -type f \( -name "*.py" -o -name "*.sh" \) | while read f; do
    echo "[FILE] $f"
    cat "$f"
    echo ""
  done
else
  echo "[WARN] utils/ not found."
fi
echo ""

###############################################################################
echo "[INFO] ============ final_extreme_monitor_v4.sh ============"
if [ -f final_extreme_monitor_v4.sh ]; then
  cat final_extreme_monitor_v4.sh
else
  echo "[WARN] final_extreme_monitor_v4.sh not found."
fi
echo ""

echo "[INFO] ============ End of cat_all_architecture.sh ============"

echo ""
echo "[NOTE] To build & run your services, do:"
echo "  docker-compose build"
echo "  docker-compose up -d"
echo ""
echo "Then to perform the advanced monitoring logic, run:"
echo "  ./final_extreme_monitor_v4.sh"
echo ""
echo "[INFO] Once verified, integrate ephemeral memory (Mongo) & multi-LLM (Tavily, Gemini, OpenAI) as needed!"
