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
