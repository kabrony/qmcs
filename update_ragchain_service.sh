#!/usr/bin/env bash
set -euo pipefail

# 1) Navigate to your project directory
cd ~/qmcs

echo "=== Step 1: Updating main.py imports ==="
# Switch from langchain_community to langchain_openai for OpenAIEmbeddings
sed -i 's/from langchain_community\.embeddings import OpenAIEmbeddings/from langchain_openai import OpenAIEmbeddings/g' ragchain_service/main.py

# Switch from langchain_community to langchain_chroma for Chroma
sed -i 's/from langchain_community\.vectorstores import Chroma/from langchain_chroma import Chroma/g' ragchain_service/main.py

echo "=== Step 2: Updating requirements.txt ==="
# Remove langchain-community
sed -i '/langchain-community/d' ragchain_service/requirements.txt

# Ensure official langchain is present
grep -qxF 'langchain' ragchain_service/requirements.txt || echo 'langchain' >> ragchain_service/requirements.txt

# Ensure langchain-openai is present
grep -qxF 'langchain-openai' ragchain_service/requirements.txt || echo 'langchain-openai' >> ragchain_service/requirements.txt

# Ensure langchain-chroma is present
grep -qxF 'langchain-chroma' ragchain_service/requirements.txt || echo 'langchain-chroma' >> ragchain_service/requirements.txt

echo "=== Requirements file after update ==="
cat ragchain_service/requirements.txt

echo "=== Step 3: Rebuilding Docker image (no cache) ==="
docker-compose build --no-cache ragchain_service

echo "=== Step 4: Bringing container up in detached mode ==="
docker-compose up -d

echo "=== Step 5: Checking logs for errors ==="
docker logs ragchain_service || true

echo "=== Done. Check the logs above for any ModuleNotFound or import errors. ==="
