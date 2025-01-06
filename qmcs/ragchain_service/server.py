import os
from fastapi import FastAPI
from motor.motor_asyncio import AsyncIOMotorClient
from tenacity import retry, stop_after_attempt, wait_fixed

app = FastAPI()

# Example environment variable or default:
MONGO_URL = os.getenv("MONGO_URL", "mongodb://mongo:27017")

db_client = None

@retry(stop=stop_after_attempt(5), wait=wait_fixed(2))
async def connect_to_mongo():
    global db_client
    db_client = AsyncIOMotorClient(MONGO_URL)
    # Use async "ping"
    await db_client.admin.command("ping")
    print("[ragchain_service] Connected to Mongo asynchronously.")

@app.on_event("startup")
async def startup_event():
    await connect_to_mongo()

@app.get("/")
async def home():
    return {"status": "Ragchain service running on port 5000"}
