import os
import logging
from fastapi import FastAPI
import uvicorn
from pymongo import MongoClient
import pandas as pd
import numpy as np
from datetime import datetime

app = FastAPI()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

MONGO_DETAILS = os.getenv('MONGO_DETAILS', '')

print("[quant_service] CODE TEST -> If you see this, code was updated.")

@app.on_event("startup")
def startup_db_client():
    global mongo_client, db
    logger.info(f"[quant_service] Attempting to connect. URI: {MONGO_DETAILS}")
    if not MONGO_DETAILS:
        logger.error("[quant_service] No MONGO_DETAILS found.")
        return
    try:
        mongo_client = MongoClient(MONGO_DETAILS)
        db = mongo_client.get_default_database()
        logger.info("[quant_service] MongoDB connected successfully")
    except Exception as e:
        logger.error(f"[quant_service] MongoDB connection error: {e}")

@app.on_event("shutdown")
def shutdown_db_client():
    if 'mongo_client' in globals():
        mongo_client.close()
        logger.info("[quant_service] MongoDB connection closed.")

@app.get("/health")
def health():
    return {
        "status": "quant_service OK",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/wallet-stats")
def wallet_stats():
    if 'db' not in globals() or db is None:
        return {"error": "No DB connection"}
    try:
        wallets_cursor = db.wallets.find({}, {"balance": 1, "recentTransactions": 1})
        wallets_list = list(wallets_cursor)
        if not wallets_list:
            return {"error": "No wallet data found"}

        df = pd.DataFrame(wallets_list)
        if 'balance' not in df.columns:
            return {"error": "No 'balance' field in wallets"}

        df['balance'] = df['balance'].fillna(0)

        avg_balance = float(df['balance'].mean())
        median_balance = float(df['balance'].median())

        if 'recentTransactions' in df.columns:
            df['tx_count'] = df['recentTransactions'].apply(lambda x: len(x) if x else 0)
            avg_tx_count = float(df['tx_count'].mean())
        else:
            avg_tx_count = 0.0

        return {
            "status": "ok",
            "wallet_count": len(df),
            "avg_balance": avg_balance,
            "median_balance": median_balance,
            "avg_tx_count": avg_tx_count,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"[quant_service] Error fetching wallet stats: {e}")
        return {"error": str(e)}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7000)
