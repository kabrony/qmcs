#!/usr/bin/env bash
#
# fix_ragchain_service.sh
# 
# Purpose:
#   1) Replaces any accidental "from langchain_text_splitter import CharacterTextSplitter"
#      with the correct "from langchain.text_splitter import CharacterTextSplitter".
#   2) Injects a fallback model = "gpt-3.5-turbo" if chosen_model is None.
# 
# Usage:
#   chmod +x fix_ragchain_service.sh
#   ./fix_ragchain_service.sh
#
# Then rebuild your Docker images:
#   docker-compose build --no-cache ragchain_service
#   docker-compose up -d ragchain_service
#
# Check logs:
#   docker logs ragchain_service
#

# 1) Navigate to your project root (adjust if needed).
cd "$(dirname "$0")/.." 2>/dev/null || cd ..

# 2) Double-check that ragchain_service/main.py exists.
if [[ ! -f "ragchain_service/main.py" ]]; then
  echo "[ERROR] ragchain_service/main.py not found! Adjust the script or your paths."
  exit 1
fi

echo "---- [STEP 1] Fixing the import line for CharacterTextSplitter ----"
# This sed command searches for 'from langchain_text_splitter import CharacterTextSplitter'
# and replaces it with 'from langchain.text_splitter import CharacterTextSplitter'
sed -i 's|from langchain_text_splitter import CharacterTextSplitter|from langchain.text_splitter import CharacterTextSplitter|g' \
  ragchain_service/main.py

echo "---- [STEP 2] Adding fallback for 'chosen_model' if None ----"
# We'll look for a line that sets 'chosen_model' in your /ask route, 
# then immediately inject a fallback if it's None
# (If your code is different, adjust the pattern or lines as needed.)

# Example: if your code has a line like:
#    chosen_model = choose_model_based_on_complexity(req.query)
# We add 2 lines after it:
#    if not chosen_model:
#        chosen_model = "gpt-3.5-turbo"

sed -i '/chosen_model\s*=\s*choose_model_based_on/d' ragchain_service/main.py
# We’ll just re-insert it with a fallback. Adjust as needed for your code’s actual lines.
#  E.g. if your function is named `choose_model_based_on_complexity(req.query)`:
sed -i '/def ask(/,/^)/ s|\(def ask.*\)|\1|; s|\(chosen_model =.*\)|chosen_model = choose_model_based_on_complexity(req.query)\n    if not chosen_model:\n        chosen_model = "gpt-3.5-turbo"|' ragchain_service/main.py

echo "[DONE] All set. Next steps:"
echo "1) docker-compose build --no-cache ragchain_service"
echo "2) docker-compose up -d ragchain_service"
echo "3) docker logs ragchain_service"
