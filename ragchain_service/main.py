import os
import logging
from fastapi import FastAPI
import uvicorn
from pymongo import MongoClient

app = FastAPI()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

MONGO_DETAILS = os.getenv('MONGO_DETAILS', '')

print("[ragchain_service] CODE TEST -> If you see this, code was updated.")

@app.on_event("startup")
def startup_db_client():
    global mongo_client, db
    logger.info(f"[ragchain_service] Attempting to connect. URI: {MONGO_DETAILS}")
    if not MONGO_DETAILS:
        logger.error("[ragchain_service] MONGO_DETAILS not set.")
        return
    try:
        mongo_client = MongoClient(MONGO_DETAILS)
        db = mongo_client.get_default_database()
        logger.info("[ragchain_service] MongoDB connected successfully")
    except Exception as e:
        logger.error(f"[ragchain_service] MongoDB connection error: {e}")

@app.on_event("shutdown")
def shutdown_db_client():
    if 'mongo_client' in globals():
        mongo_client.close()
        logger.info("[ragchain_service] MongoDB connection closed.")

@app.get("/health")
def health():
    return {"status": "ragchain_service OK"}

@app.get("/analyze-wallet/{address}")
def analyze_wallet(address: str):
    if 'db' not in globals() or db is None:
        return {"error": "DB not connected"}
    wallets_coll = db.get_collection("wallets")
    doc = wallets_coll.find_one({"address": address})
    if not doc:
        return {"error": "No such wallet in DB"}
    return {
        "address": doc.get("address"),
        "balance": doc.get("balance", 0),
        "tx_count": len(doc.get("recentTransactions", []))
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
