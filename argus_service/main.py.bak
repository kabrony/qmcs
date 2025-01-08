import psutil
import os
import httpx
import traceback
from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv(
app = FastAPI(

@app.get("/health"
async def health_check():
    # Return 'healthy' to match VOTS expectations
    return {"status": "healthy", "service": "argus_service"}

@app.get("/metrics"
async def get_metrics():
    mem = psutil.virtual_memory(
    cpu_percent = psutil.cpu_percent(interval=1
    return {
        "cpu_usage": cpu_percent,
        "memory_usage": f"{mem.percent:.2f}%"

@app.get("/test_solana_agents"
async def check_solana_health():
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get("http://solana_agents:5106/health", timeout=5
        if resp.status_code == 200:
            return resp.json(
        else:
            return {"status": "error","message":"No response from solana_agents service"}
    except Exception as e:
        traceback.print_exc(
        return {"status":"error","message":str(e)}














