#!/bin/bash
#
# Updates import statements, modifies requirements.txt, rebuilds the Docker
# image, and checks logs for errors for the ragchain_service.
#

set -e

PROJECT_DIR="." # Assuming script is in the project directory

echo "[INFO] Updating import statements in main.py..."
sed -i 's/from langchain_community.llms import OpenAI/from langchain_openai import OpenAI/g' "$PROJECT_DIR/main.py"
sed -i 's/from langchain_community.vectorstores import Chroma/from langchain_chroma import Chroma/g' "$PROJECT_DIR/main.py"

echo "[INFO] Modifying requirements.txt..."
# Remove langchain-community
sed -i '/langchain-community/d' "$PROJECT_DIR/requirements.txt"

# Add langchain, langchain-openai, and langchain-chroma if not present
if ! grep -q 'langchain' "$PROJECT_DIR/requirements.txt"; then
  echo "langchain" >> "$PROJECT_DIR/requirements.txt"
fi
if ! grep -q 'langchain-openai' "$PROJECT_DIR/requirements.txt"; then
  echo "langchain-openai" >> "$PROJECT_DIR/requirements.txt"
fi
if ! grep -q 'langchain-chroma' "$PROJECT_DIR/requirements.txt"; then
  echo "langchain-chroma" >> "$PROJECT_DIR/requirements.txt"
fi

echo "[INFO] Rebuilding Docker image with no cache..."
docker-compose build --no-cache

echo "[INFO] Verifying logs for ModuleNotFoundError..."
if docker-compose logs 2>&1 | grep -q "ModuleNotFoundError"; then
  echo "[ERROR] ModuleNotFoundError found in the logs. Check your dependencies."
else
  echo "[INFO] No ModuleNotFoundError found in the logs."
fi

echo "[INFO] Update and rebuild process completed."
