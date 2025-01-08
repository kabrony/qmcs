#!/usr/bin/env bash
#
# create_ragchain_service.sh
# Re-creates ragchain_service from scratch with Motor-based async code.

mkdir -p ragchain_service

# 1) Dockerfile
cat > ragchain_service/Dockerfile <<'DOCKERFILE_EOF'
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

# 2) main.py
cat > ragchain_service/main.py <<'MAIN_EOF'
import os
from fastapi import FastAPI
from motor.motor_asyncio import AsyncIOMotorClient
from tenacity import retry, stop_after_attempt, wait_fixed

app = FastAPI()
MONGO_URL = os.getenv("MONGO_URL", "mongodb://mongo:27017")

db_client = None

@retry(stop=stop_after_attempt(5), wait=wait_fixed(2))
async def connect_to_mongo():
    global db_client
    db_client = AsyncIOMotorClient(MONGO_URL)
    result = await db_client.admin.command("ping")
    print("[ragchain_service] ping result:", result)

@app.on_event("startup")
async def startup_event():
    await connect_to_mongo()
    print("[ragchain_service] Connected to Mongo via Motor (async).")

@app.get("/")
async def home():
    return {"status": "Ragchain service running on port 5000"}
MAIN_EOF

echo "[OK] Created fresh ragchain_service folder with Motor-based Dockerfile + main.py."
echo "Next steps:"
echo "  1) chmod +x create_ragchain_service.sh"
echo "  2) ./create_ragchain_service.sh"
echo "  3) docker-compose build --no-cache ragchain-service"
echo "  4) docker-compose up --force-recreate ragchain-service"
