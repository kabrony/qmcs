#!/usr/bin/env bash

# Filename: fix_ragchain_imports.sh
# Purpose:
#  1. Fix the incorrect "langchain_text_splitter" import in ragchain_service/main.py
#  2. Remove any mention of "langchain_text_splitter" in ragchain_service/requirements.txt
#  3. Rebuild the Docker image/container for ragchain_service
#  4. Show the container logs

set -e

echo "[INFO] Removing 'langchain_text_splitter' references in main.py..."
sed -i 's/from langchain_text_splitter import CharacterTextSplitter/from langchain.text_splitter import CharacterTextSplitter/g' ragchain_service/main.py || true

echo "[INFO] Removing 'langchain_text_splitter' from ragchain_service/requirements.txt..."
sed -i '/langchain_text_splitter/d' ragchain_service/requirements.txt || true

echo "[INFO] Rebuilding ragchain_service Docker image..."
docker-compose build ragchain_service

echo "[INFO] Restarting ragchain_service container..."
docker-compose up -d ragchain_service

echo "[INFO] Tail logs for ragchain_service to verify the fix:"
docker-compose logs -f ragchain_service
