import os
from fastapi import FastAPI
from motor.motor_asyncio import AsyncIOMotorClient
from tenacity import retry, stop_after_attempt, wait_fixed

app = FastAPI()
MONGO_URL = os.getenv("MONGO_URL", "mongodb://mongo:27017")

db_client = None

@retry(stop=stop_after_attempt(5), wait=wait_fixed(2))
async def connect_mongo():
    global db_client
    db_client = AsyncIOMotorClient(MONGO_URL)
    # Test ping
    result = await db_client.admin.command("ping")
    print("[ragchain_service] ping result:", result)

@app.on_event("startup")
async def startup_event():
    await connect_mongo()
    print("[ragchain_service] Connected to Mongo via Motor async")

@app.get("/")
async def home():
    return {"status": "Ragchain service running on port 5000"}
