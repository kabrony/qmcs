#!/usr/bin/env bash
#
# fix_ragchain.sh
#
# Overwrites ALL ragchain_service code to ensure Motor-based async usage.
# Usage:
#   chmod +x fix_ragchain.sh
#   ./fix_ragchain.sh
#   cd qmcs && docker-compose up --build
#

#############################################
#  Overwrite ragchain_service Dockerfile
#############################################
cat > qmcs/ragchain_service/Dockerfile <<'DOCKERFILE_EOF'
FROM python:3.10-slim

WORKDIR /app

# Minimal system deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential curl && \
    rm -rf /var/lib/apt/lists/*

# Install only Motor and the needed libs (no PyMongo!)
RUN pip install --no-cache-dir \
    motor \
    fastapi \
    uvicorn \
    requests \
    tenacity

COPY . /app

EXPOSE 5000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
DOCKERFILE_EOF

#############################################
#  Overwrite ragchain_service/main.py
#############################################
cat > qmcs/ragchain_service/main.py <<'MAIN_EOF'
import os
from fastapi import FastAPI
from motor.motor_asyncio import AsyncIOMotorClient
from tenacity import retry, stop_after_attempt, wait_fixed

app = FastAPI()

# Use "mongo" hostname (Docker Compose service name), port 27017
MONGO_URL = os.getenv("MONGO_URL", "mongodb://mongo:27017")
db_client = None

@retry(stop=stop_after_attempt(5), wait=wait_fixed(2))
async def connect_to_mongo():
    global db_client
    db_client = AsyncIOMotorClient(MONGO_URL)
    # This is valid with Motor:
    result = await db_client.admin.command("ping")
    print("[ragchain_service] ping result:", result)

@app.on_event("startup")
async def startup_event():
    await connect_to_mongo()
    print("[ragchain_service] Connected to Mongo asynchronously via Motor.")

@app.get("/")
async def home():
    return {"status": "Ragchain service running on port 5000"}
MAIN_EOF

echo "============================================"
echo "[OK] All ragchain_service files overwritten."
echo "Next steps:"
echo "  1) chmod +x fix_ragchain.sh"
echo "  2) ./fix_ragchain.sh"
echo "  3) cd qmcs && docker-compose up --build"
echo "============================================"
