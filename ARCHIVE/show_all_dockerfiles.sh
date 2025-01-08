#!/usr/bin/env bash
set -e

# List of service folders that may contain Dockerfiles
services=(trilogy_app argus_service oracle_service openai_service quant_service ragchain_service solana_agents)

for service in "${services[@]}"; do
  echo "===== Dockerfile in $service/ ====="
  if [ -f "$service/Dockerfile" ]; then
    cat "$service/Dockerfile"
  else
    echo "(No Dockerfile found in $service/)"
  fi
  echo
done

echo "===== Dockerfile in root folder (if any) ====="
if [ -f Dockerfile ]; then
  cat Dockerfile
else
  echo "(No Dockerfile found in root folder)"
fi
echo
