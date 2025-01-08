#!/usr/bin/env bash
###############################################################################
# cat_debug_files.sh
#
# A small helper script that prints out the contents of your main Python/JS
# files so you can share them (e.g., in a gist or pastebin) for debugging.
###############################################################################

# Make sure we’re in the qmcs root or adjust paths accordingly.

echo "======================="
echo " openai_service/main.py"
echo "======================="
if [[ -f openai_service/main.py ]]; then
  cat openai_service/main.py
else
  echo "[WARNING] openai_service/main.py not found!"
fi

echo
echo "============================="
echo " openai_service/model_selection.py"
echo "============================="
if [[ -f openai_service/model_selection.py ]]; then
  cat openai_service/model_selection.py
else
  echo "[WARNING] openai_service/model_selection.py not found!"
fi

echo
echo "==================="
echo " solana_agents/index.js"
echo "==================="
if [[ -f solana_agents/index.js ]]; then
  cat solana_agents/index.js
else
  echo "[WARNING] solana_agents/index.js not found!"
fi

echo
echo "==========================="
echo " ragchain_service/main.py"
echo "==========================="
if [[ -f ragchain_service/main.py ]]; then
  cat ragchain_service/main.py
else
  echo "[WARNING] ragchain_service/main.py not found!"
fi

echo
echo "========================="
echo " quant_service/main.py"
echo "========================="
if [[ -f quant_service/main.py ]]; then
  cat quant_service/main.py
else
  echo "[WARNING] quant_service/main.py not found!"
fi

echo
echo "========================="
echo " oracle_service/main.py"
echo "========================="
if [[ -f oracle_service/main.py ]]; then
  cat oracle_service/main.py
else
  echo "[WARNING] oracle_service/main.py not found!"
fi

echo
echo "========================"
echo " argus_service/main.py"
echo "========================"
if [[ -f argus_service/main.py ]]; then
  cat argus_service/main.py
else
  echo "[WARNING] argus_service/main.py not found!"
fi

echo
echo "==========================="
echo " vots_unified_dashboard.sh"
echo "==========================="
if [[ -f vots_unified_dashboard.sh ]]; then
  cat vots_unified_dashboard.sh
else
  echo "[WARNING] vots_unified_dashboard.sh not found!"
fi

echo
echo "[INFO] Done displaying files. If you need others, add them to this script!"
