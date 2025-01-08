#!/usr/bin/env bash
set -e

# This script finds Dockerfiles in known service folders
# and optionally updates them (copy to another file).
# Adjust the services array, file names, or copy logic as needed.

SERVICES=(
  "argus_service"
  "oracle_service"
  "openai_service"
  "quant_service"
  "ragchain_service"
  "solana_agents"
)

ROOT_DOCKERFILE="Dockerfile"  # Name of Dockerfile if in the root
FILE_TO_UPDATE="Dockerfile"   # The existing Dockerfile name

# Optionally, define a location to copy updated Dockerfiles
# e.g., "Dockerfile.updated" or some version backup name
UPDATED_SUFFIX=".updated"

echo "[INFO] Starting script to cat (show) Dockerfiles (and optionally copy)."

for service in "${SERVICES[@]}"; do
  echo "------------------------------"
  echo "[SERVICE] $service"
  
  # Check if Dockerfile exists
  if [ -f "$service/$FILE_TO_UPDATE" ]; then
    echo "[INFO] Found $service/$FILE_TO_UPDATE"
    echo "----- CONTENT BEGIN -----"
    cat "$service/$FILE_TO_UPDATE"
    echo "----- CONTENT END   -----"
    
    # Uncomment the following line if you want to copy/update the Dockerfile
    # cp "$service/$FILE_TO_UPDATE" "$service/$FILE_TO_UPDATE$UPDATED_SUFFIX"
    # echo "[INFO] Copied to $service/$FILE_TO_UPDATE$UPDATED_SUFFIX"
    
  else
    echo "[WARN] No $FILE_TO_UPDATE found in $service/"
  fi
done

# Optionally handle a Dockerfile in the root folder
if [ -f "$ROOT_DOCKERFILE" ]; then
  echo "------------------------------"
  echo "[ROOT] $ROOT_DOCKERFILE"
  echo "----- CONTENT BEGIN -----"
  cat "$ROOT_DOCKERFILE"
  echo "----- CONTENT END   -----"
  
  # Uncomment if you want to copy/update the root Dockerfile
  # cp "$ROOT_DOCKERFILE" "$ROOT_DOCKERFILE$UPDATED_SUFFIX"
  # echo "[INFO] Copied to $ROOT_DOCKERFILE$UPDATED_SUFFIX"
fi

echo "[DONE] Completed showing Dockerfiles."
