#!/usr/bin/env bash
set -e

###########################################################
# fix_ragchain.sh
#
# A one-stop script to:
# 1) Overwrite ragchain_service/main.py with valid Python.
# 2) Remove invalid lines (e.g., `prompt =`).
# 3) Use correct LangChain imports.
# 4) Build & restart the container.
###########################################################

# Ensure we're in the project root
cd "$(dirname "$0")"

echo "[INFO] Writing a new main.py into ragchain_service/..."

# Create or overwrite ragchain_service/main.py
cat <<"MAIN_PY" > ragchain_service/main.py
import os
import logging
from datetime import datetime
from dotenv import load_dotenv

from fastapi import FastAPI, HTTPException
import uvicorn
from motor.motor_asyncio import AsyncIOMotorClient
from tenacity import retry, stop_after_attempt, wait_fixed
import asyncio

# If you use OpenAI
import openai

# If you use Google Generative AI (Gemini)
import google.generativeai as genai

# Official LangChain imports
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.vectorstores import Chroma
from langchain.text_splitter import CharacterTextSplitter
from langchain.docstore.document import Document

load_dotenv()

app = FastAPI()

MONGO_URL = os.getenv("MONGO_URL", "mongodb://mongo:27017")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
db_client = None
ephemeral_thoughts = []

# Configure OpenAI
openai.api_key = OPENAI_API_KEY

# Configure Gemini if you use it
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    # Example usage:
    # gemini_model = genai.GenerativeModel('gemini-pro')

embeddings = OpenAIEmbeddings(
    disallowed_special=(),
    openai_api_key=OPENAI_API_KEY,
    model_name="text-embedding-ada-002"  # Adjust if needed
)

vectorstore = Chroma(
    collection_name="my_longterm_memory",
    embedding_function=embeddings,
    persist_directory="/app/chroma_storage"
)

@retry(stop=stop_after_attempt(5), wait=wait_fixed(2))
async def connect_to_mongo():
    global db_client
    db_client = AsyncIOMotorClient(MONGO_URL)
    result = await db_client.admin.command("ping")
    logging.info(f"[ragchain_service] ping: {result}")

@app.on_event("startup")
async def startup_event():
    logging.info("[ragchain_service] Attempting to connect to Mongo...")
    await connect_to_mongo()
    logging.info("[ragchain_service] Connected to Mongo (async).")

@app.get("/")
async def root():
    return {"message": "ragchain_service is running smoothly."}

def run_app():
    uvicorn.run("main:app", host="0.0.0.0", port=5000, reload=False)

if __name__ == "__main__":
    run_app()
MAIN_PY

echo "[INFO] main.py written successfully."

# Now rebuild & restart ragchain_service
echo "[INFO] Rebuilding Docker image for ragchain_service..."
docker-compose build ragchain_service

echo "[INFO] Bringing ragchain_service back up..."
docker-compose up -d ragchain_service

echo "[DONE] fix_ragchain.sh completed successfully."
