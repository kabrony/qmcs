#!/usr/bin/env bash

# This script ensures 'langchain' is in ragchain_service/requirements.txt,
# fixes the import from 'langchain_text_splitter' to 'langchain.text_splitter',
# rebuilds the Docker image, and restarts the container.

set -e

REQS_FILE="ragchain_service/requirements.txt"

echo "[INFO] Removing references to old or missing langchain packages..."
sed -i '/langchain_text_splitter/d' "$REQS_FILE" || true
sed -i '/langchain-community/d'     "$REQS_FILE" || true
sed -i '/langchain$/d'              "$REQS_FILE" || true

echo "[INFO] Ensuring 'langchain' is in requirements..."
grep -qxF 'langchain>=0.0.200' "$REQS_FILE" || echo 'langchain>=0.0.200' >> "$REQS_FILE"

echo "[INFO] Ensuring 'langchain-chroma' is in requirements..."
grep -qxF 'langchain-chroma' "$REQS_FILE" || echo 'langchain-chroma' >> "$REQS_FILE"

echo "[INFO] Ensuring 'langchain-openai' is in requirements..."
grep -qxF 'langchain-openai' "$REQS_FILE" || echo 'langchain-openai' >> "$REQS_FILE"

echo "[INFO] Ensuring 'chromadb' is in requirements..."
grep -qxF 'chromadb' "$REQS_FILE" || echo 'chromadb' >> "$REQS_FILE"

echo "[INFO] (Optional) Ensuring 'google-generativeai' if used..."
grep -qxF 'google-generativeai' "$REQS_FILE" || echo 'google-generativeai' >> "$REQS_FILE"

echo "[INFO] Fixing import in ragchain_service/main.py..."
sed -i 's|from langchain_text_splitter import CharacterTextSplitter|from langchain.text_splitter import CharacterTextSplitter|g' ragchain_service/main.py || true

# In case it's referencing 'ModuleNotFoundError: No module named 'langchain_text_splitter''
#   we switch to the official langchain import:
#   from langchain.text_splitter import CharacterTextSplitter

echo "[INFO] Rebuilding the ragchain_service Docker image..."
docker-compose build ragchain_service

echo "[INFO] Restarting ragchain_service container..."
docker-compose up -d ragchain_service

echo "[INFO] Tailing logs for ragchain_service (Ctrl+C to stop):"
docker-compose logs -f ragchain_service
