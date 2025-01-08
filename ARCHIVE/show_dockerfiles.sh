#!/usr/bin/env bash
set -e

echo "======================"
echo "[INFO] Dockerfile in trilogy_app (if present)"
echo "======================"
cat trilogy_app/Dockerfile 2>/dev/null || echo "No Dockerfile found in trilogy_app/"

echo "======================"
echo "[INFO] Dockerfile in argus_service"
echo "======================"
cat argus_service/Dockerfile 2>/dev/null || echo "No Dockerfile found in argus_service/"

echo "======================"
echo "[INFO] Dockerfile in oracle_service"
echo "======================"
cat oracle_service/Dockerfile 2>/dev/null || echo "No Dockerfile found in oracle_service/"

echo "======================"
echo "[INFO] Dockerfile in openai_service"
echo "======================"
cat openai_service/Dockerfile 2>/dev/null || echo "No Dockerfile found in openai_service/"

echo "======================"
echo "[INFO] Dockerfile in quant_service"
echo "======================"
cat quant_service/Dockerfile 2>/dev/null || echo "No Dockerfile found in quant_service/"

echo "======================"
echo "[INFO] Dockerfile in ragchain_service"
echo "======================"
cat ragchain_service/Dockerfile 2>/dev/null || echo "No Dockerfile found in ragchain_service/"

echo "======================"
echo "[INFO] Dockerfile in solana_agents"
echo "======================"
cat solana_agents/Dockerfile 2>/dev/null || echo "No Dockerfile found in solana_agents/"

echo "======================"
echo "[INFO] Dockerfile in root (if using Dockerfile in .)"
echo "======================"
cat Dockerfile 2>/dev/null || echo "No Dockerfile found in root folder"

echo
echo "[DONE] Displayed all Dockerfiles found."
