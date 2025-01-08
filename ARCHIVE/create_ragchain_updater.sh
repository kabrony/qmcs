#!/usr/bin/env bash
#
# create_ragchain_updater.sh
#
# This script creates a "ragchain_service" folder with the necessary files
# to update and rebuild the service.
#
# Files created:
#   - ragchain_service/main.py
#   - ragchain_service/requirements.txt
#   - ragchain_service/docker-compose.yml
#   - ragchain_service/update_and_rebuild.sh
#
# The script then shows how to use the update script.
#
# Usage:
#   chmod +x create_ragchain_updater.sh
#   ./create_ragchain_updater.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$HOME/qmcs/ragchain_service"

echo "[INFO] Creating folder $PROJECT_DIR ..."
mkdir -p "$PROJECT_DIR"

###################################
# 1) main.py (placeholder)
###################################
cat > "$PROJECT_DIR/main.py" << 'EOF_MAIN'
from langchain_community.llms import OpenAI  # Will be replaced
from langchain_community.vectorstores import Chroma  # Will be replaced

def main():
    print("Placeholder for ragchain_service main.py")
    llm = OpenAI()
    vectorstore = Chroma()
    # ... your service logic here ...

if __name__ == "__main__":
    main()
EOF_MAIN

echo "[OK] Created $PROJECT_DIR/main.py"

###################################
# 2) requirements.txt (initial)
###################################
cat > "$PROJECT_DIR/requirements.txt" << 'EOF_REQ'
langchain-community
# Add other initial dependencies here
EOF_REQ

echo "[OK] Created $PROJECT_DIR/requirements.txt"

###################################
# 3) docker-compose.yml (minimal example)
###################################
cat > "$PROJECT_DIR/docker-compose.yml" << 'EOF_DOCKER'
version: '3.8'
services:
  ragchain_app:
    build: .
    ports:
      - "8080:8080"
    volumes:
      - .:/app
    environment:
      - PYTHONUNBUFFERED=1
    command: python main.py
EOF_DOCKER

echo "[OK] Created $PROJECT_DIR/docker-compose.yml"

###################################
# 4) update_and_rebuild.sh
###################################
cat > "$PROJECT_DIR/update_and_rebuild.sh" << 'EOF_UPDATE'
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
EOF_UPDATE

chmod +x "$PROJECT_DIR/update_and_rebuild.sh"
echo "[OK] Created $PROJECT_DIR/update_and_rebuild.sh (executable)"

###################################
# DONE
###################################
echo "-------------------------------------------------"
echo "[SUCCESS] Files created in $PROJECT_DIR."
echo "Next steps:"
echo "1) Navigate to the ragchain_service directory:"
echo "   cd $PROJECT_DIR"
echo ""
echo "2) Run the update and rebuild script:"
echo "   ./update_and_rebuild.sh"
echo ""
echo "3) (Optional) Start the Docker container:"
echo "   docker-compose up"
echo ""
echo "4) Check container logs:"
echo "   docker-compose logs -f"
echo "-------------------------------------------------"
