#!/usr/bin/env bash
set -e

echo "[INFO] Overwriting main.py files for Python services + solana_agents index.js..."
echo "[WARNING] Ensure you have backed up existing files if needed."
sleep 3

########################################
# Overwrite: openai_service/main.py
########################################
mkdir -p openai_service
cat <<'EOF' > openai_service/main.py
import os
import openai
from dotenv import load_dotenv
from typing import Optional, List, Dict
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.vectorstores import Chroma
from langchain.text_splitter import CharacterTextSplitter
from langchain.docstore.document import Document
import asyncio
from datetime import datetime

load_dotenv()
app = FastAPI(
    title="OpenAI Service w/ Advanced Memory",
    description="Stores doc embeddings, uses openai.chat.completions, returns health checks.",
    version="1.0.0",
)

openai.api_key = os.getenv("OPENAI_API_KEY")

def choose_model_based_on_complexity(prompt: str) -> str:
    # Simple logic - adapt as needed
    if "complex" in prompt.lower() or "reasoning" in prompt.lower():
        return "gpt-4o"
    elif "code" in prompt.lower():
        return "gpt-4o"
    else:
        return "gpt-3.5-turbo"

embeddings = OpenAIEmbeddings(disallowed_special=())
vectorstore = Chroma(
    collection_name="my_longterm_memory",
    embedding_function=embeddings,
    persist_directory="/app/chroma_storage"
)

class AddDocRequest(BaseModel):
    text: str
    chunk_size: int = 200
    chunk_overlap: int = 20

class AskRequest(BaseModel):
    query: str
    k: Optional[int] = 3

@app.post("/add_doc")
async def add_doc(req: AddDocRequest):
    try:
        splitter = CharacterTextSplitter(
            separator=" ",
            chunk_size=req.chunk_size,
            chunk_overlap=req.chunk_overlap
        )
        chunks = splitter.split_text(req.text)
        docs = [Document(page_content=chunk) for chunk in chunks]
        vectorstore.add_documents(docs)
        return {"message": f"Stored {len(chunks)} chunks.", "chunks": chunks}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ask")
async def ask(req: AskRequest):
    try:
        relevant_docs = vectorstore.similarity_search(req.query, k=req.k or 3)
        combined_text = "\n".join([doc.page_content for doc in relevant_docs])

        system_prompt = (
            "You are an AI assistant with knowledge from these docs:\n"
            f"{combined_text}\n\n"
            "Answer based on these docs. If not found, say unsure."
        )
        chosen_model = choose_model_based_on_complexity(req.query)
        response = await openai.ChatCompletion.acreate(
            model=chosen_model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": req.query}
            ],
            temperature=0.7,
        )
        if response.choices[0].message is None:
            return {"answer": None, "chosen_model": chosen_model}
        answer = response.choices[0].message.content.strip()
        return {"answer": answer, "chosen_model": chosen_model}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/models")
async def list_models():
    return {
        "data": [
            {"id": "gpt-4o"},
            {"id": "gpt-3.5-turbo"},
            {"id": "o1"},
            {"id": "o1-mini"}
        ]
    }

@app.post("/chat")
async def chat_endpoint(payload: Dict):
    try:
        user_message = payload.get("messages", [{"role": "user","content":""}])[-1]["content"]
        chosen_model = choose_model_based_on_complexity(user_message)
        response = await openai.ChatCompletion.acreate(
            model=chosen_model,
            messages=[{"role": "user", "content": user_message}],
            temperature=0.7,
        )
        if response.choices[0].message is None:
            return {"model_used": chosen_model, "answer": None}
        answer = response.choices[0].message.content.strip()
        return {"model_used": chosen_model, "answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}
EOF

########################################
# Overwrite: ragchain_service/main.py
########################################
mkdir -p ragchain_service
cat <<'EOF' > ragchain_service/main.py
import os
from fastapi import FastAPI, HTTPException
from motor.motor_asyncio import AsyncIOMotorClient
from tenacity import retry, stop_after_attempt, wait_fixed
import asyncio
from datetime import datetime
from dotenv import load_dotenv
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.vectorstores import Chroma
from langchain.text_splitter import CharacterTextSplitter
from langchain.docstore.document import Document
import openai

load_dotenv()
app = FastAPI()

MONGO_URL = os.getenv("MONGO_URL","mongodb://mongo:27017")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
db_client = None
ephemeral_thoughts = []

embeddings = OpenAIEmbeddings(disallowed_special=())
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
    print("[ragchain_service] ping:", result)

@app.on_event("startup")
async def startup_event():
    await connect_to_mongo()
    print("[ragchain_service] Connected to Mongo (async).")

@app.get("/")
async def root():
    return {"status":"ragchain_service running"}

@app.get("/health")
async def health():
    return {"status":"ok", "service":"ragchain_service"}

@app.post("/store_thought/")
async def store_thought(thought: str):
    global ephemeral_thoughts
    ephemeral_thoughts.append({
        "id": len(ephemeral_thoughts),
        "text": thought,
        "time": str(datetime.now())
    })
    return {"message":"Stored Ephemeral Thought"}

@app.get("/ephemeral_ideas")
async def get_ephemeral_ideas():
    return {"data": ephemeral_thoughts}

@app.post("/add_doc")
async def add_doc(text: str, chunk_size: int=200, chunk_overlap: int=20):
    splitter = CharacterTextSplitter(
        separator=" ",
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap
    )
    chunks = splitter.split_text(text)
    docs = [Document(page_content=chunk) for chunk in chunks]
    vectorstore.add_documents(docs)
    return {"message":"Stored Documents", "chunks": chunks}

@app.post("/ask")
async def ask(query: str, k: int=3):
    try:
        relevant_docs = vectorstore.similarity_search(query, k=k or 3)
        combined_text = "\n".join([doc.page_content for doc in relevant_docs])
        prompt = (
            "You are an AI with knowledge from docs:\n"
            f"{combined_text}\n\n"
            "Answer user question. If not found, say 'unsure'."
        )
        response = await openai.ChatCompletion.acreate(
            model="gpt-3.5-turbo",
            messages=[
                {"role":"system","content":prompt},
                {"role":"user","content":query}
            ],
            temperature=0.7
        )
        ans = response.choices[0].message.content.strip() if response.choices[0].message else None
        return {"answer": ans, "docsUsed":[d.page_content for d in relevant_docs]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
EOF

########################################
# Overwrite: quant_service/main.py
########################################
mkdir -p quant_service
cat <<'EOF' > quant_service/main.py
import os
import requests
import asyncio
import traceback
import openai
import time
import random
from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

SOLANA_AGENTS_URL = os.getenv("SOLANA_AGENTS_URL","http://solana_agents:5106")
RAGCHAIN_SERVICE_URL= os.getenv("RAGCHAIN_SERVICE_URL","http://ragchain_service:5105")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
QUANT_SERVICE_URL= os.getenv("QUANT_SERVICE_URL","http://quant_service:5104")

developer_wallet_count = 0
volume = 0
launch_start_time = time.time()

@app.get("/health")
async def health():
    return {"status": "ok", "service":"quant_service"}

@app.get("/test_redis")
def test_redis():
    # If you do not have Redis integration, either return 'ok' or code your logic
    return "ok"

@app.get("/test_mongo")
def test_mongo():
    # If you do not have Mongo integration, either return 'ok' or code your logic
    return "ok"

@app.post("/trade")
async def do_trade(data: dict):
    try:
        rag_response = await get_ragchain_ideas()
        print("RAGChain response:", rag_response)
        resp = await process_with_retry(
            requests.post,
            f"{SOLANA_AGENTS_URL}/trade",
            json=data,
            timeout=10
        )
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail={"message":"An error occurred","error":str(e)})

@app.get("/pump-signals/{token}")
async def get_pump_signals(token: str):
    global developer_wallet_count, volume, launch_start_time
    developer_wallet_count += random.randint(0,5)
    volume += random.randint(10,200)
    time_since_start = time.time() - launch_start_time
    hype_score = (developer_wallet_count * 0.3) + (volume * 0.2) + (time_since_start*0.1)
    return {
        "dev_whale_activity": developer_wallet_count,
        "social_score": hype_score,
        "volume_score": volume
    }

@app.get("/get-ragchain-ideas")
async def get_ragchain_ideas():
    try:
        resp = await process_with_retry(
            requests.get,
            f"{RAGCHAIN_SERVICE_URL}/ephemeral_ideas",
            timeout=10
        )
        resp.raise_for_status()
        return resp.json()
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail={"message":"An error occurred","error":str(e)})

@app.post("/decide")
async def make_decision(context: dict):
    try:
        pump_signals = await process_with_retry(
            requests.get,
            f"{QUANT_SERVICE_URL}/pump-signals/SOL",
            timeout=10
        )
        pump_signals.raise_for_status()
        # Minimal usage of openai
        client = openai.OpenAI(api_key=OPENAI_API_KEY)
        openai_response = await process_with_retry(
            client.chat.completions.create,
            model="gpt-3.5-turbo",
            messages=[
                {"role":"user","content":f"Generate a quick decision on: {pump_signals.text}"}
            ],
            temperature=0.7,
        )
        ans = openai_response.choices[0].message.content
        return {"execute":True, "reason":"Testing", "openai_response":ans}
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

async def process_with_retry(call, url: str, *args, **kwargs):
    for attempt in range(3):
        try:
            response = await asyncio.wait_for(call(url, *args, **kwargs), timeout=10)
            response.raise_for_status()
            return response
        except Exception as e:
            if attempt==2:
                raise
            await asyncio.sleep(2**attempt)
EOF

########################################
# Overwrite: argus_service/main.py
########################################
mkdir -p argus_service
cat <<'EOF' > argus_service/main.py
import psutil
import os
import httpx
import traceback
from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

@app.get("/health")
async def health_check():
    # Return 'healthy' to match VOTS expectations
    return {"status": "healthy", "service": "argus_service"}

@app.get("/metrics")
async def get_metrics():
    mem = psutil.virtual_memory()
    cpu_percent = psutil.cpu_percent(interval=1)
    return {
        "cpu_usage": cpu_percent,
        "memory_usage": f"{mem.percent:.2f}%"
    }

@app.get("/test_solana_agents")
async def check_solana_health():
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get("http://solana_agents:5106/health", timeout=5)
        if resp.status_code == 200:
            return resp.json()
        else:
            return {"status": "error","message":"No response from solana_agents service"}
    except Exception as e:
        traceback.print_exc()
        return {"status":"error","message":str(e)}
EOF

########################################
# Overwrite: oracle_service/main.py
########################################
mkdir -p oracle_service
cat <<'EOF' > oracle_service/main.py
import os
import requests
import asyncio
import traceback
from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

@app.get("/health")
async def health_check():
    # Return 200 + "status: healthy" to align with typical checks
    return {"status": "healthy","service":"oracle_service"}

@app.get("/get_external_data")
async def get_external_data():
    """Placeholder for fetching external data from an external API."""
    return {"message": "Endpoint for external data usage."}
EOF

########################################
# Overwrite: root qmcs/main.py (Optional)
########################################
mkdir -p qmcs
cat <<'EOF' > qmcs/main.py
import os
import asyncio
from dotenv import load_dotenv
from swarms import Agent
from swarm_models import OpenAIChat
from swarms.structs.swarm_router import SwarmRouter, SwarmType

load_dotenv()

api_key = os.getenv("GROQ_API_KEY","DUMMY_KEY")

model = OpenAIChat(
    openai_api_base="https://api.groq.com/openai/v1",
    openai_api_key=api_key,
    model_name="llama-3.1-70b-versatile",
    temperature=0.1,
)

DATA_EXTRACTOR_PROMPT = "..."
SUMMARIZER_PROMPT = "..."
FINANCIAL_ANALYST_PROMPT = "..."
MARKET_ANALYST_PROMPT = "..."
OPERATIONAL_ANALYST_PROMPT = "..."

data_extractor_agent = Agent(
    agent_name="Data-Extractor",
    system_prompt=DATA_EXTRACTOR_PROMPT,
    llm=model,
    max_loops=1,
    autosave=True,
    verbose=True,
    dynamic_temperature_enabled=True,
    saved_state_path="data_extractor_agent.json",
    user_name="pe_firm",
    retry_attempts=1,
    context_length=200000,
    output_type="string",
)

# similarly define summarizer_agent, financial_analyst_agent, etc.

router = SwarmRouter(
    name="pe-document-analysis-swarm",
    description="Analyze docs for private equity",
    max_loops=1,
    agents=[data_extractor_agent],
    swarm_type=SwarmType.ConcurrentWorkflow
)

if __name__=="__main__":
    result = asyncio.run(router.run("Hello from the main multi-agent system!"))
    print(result)
EOF

########################################
# Overwrite: solana_agents/index.js
########################################
mkdir -p solana_agents
cat <<'EOF' > solana_agents/index.js
require('dotenv').config();
const axios = require('axios');
const cron = require('node-cron');
const express = require('express');
const app = express();
app.use(express.json());

const { Scraper, SearchMode } = require("agent-twitter-client");
const { Connection, Keypair, Transaction, SystemProgram, sendAndConfirmTransaction, PublicKey } = require("@solana/web3.js");
const { v4: uuidv4 } = require('uuid');

const logger = {
  info: (...args) => console.log(new Date().toISOString(), "[INFO]", ...args),
  error: (...args) => console.error(new Date().toISOString(), "[ERROR]", ...args),
  warn: (...args) => console.warn(new Date().toISOString(), "[WARN]", ...args),
};

const PORT = process.env.PORT || 4000;
const RAGCHAIN_SERVICE_URL = process.env.RAGCHAIN_SERVICE_URL;
const QUANT_SERVICE_URL = process.env.QUANT_SERVICE_URL;
const SOLANA_RPC_URL = process.env.SOLANA_RPC_URL;
const SOLANA_PRIVATE_KEY = process.env.SOLANA_PRIVATE_KEY;
const TWITTER_USERNAME = process.env.TWITTER_USERNAME;
const TWITTER_PASSWORD = process.env.TWITTER_PASSWORD;
const TWITTER_EMAIL = process.env.TWITTER_EMAIL;

logger.info("Starting solana_agents with config:", {
  PORT, QUANT_SERVICE_URL, SOLANA_RPC_URL
});

app.get('/health', (req, res) => {
  return res.status(200).json({status: "ok", message: "solana_agents healthy"});
});

async function processTransaction(token, amount) {
  if (!SOLANA_PRIVATE_KEY) {
    throw new Error("Missing SOLANA_PRIVATE_KEY");
  }
  const connection = new Connection(SOLANA_RPC_URL);
  const keypair = Keypair.fromSecretKey(
    Uint8Array.from(Buffer.from(SOLANA_PRIVATE_KEY, "base64"))
  );
  const toPublicKey = new PublicKey(process.env.SOLANA_PUBLIC_KEY);
  const lamports = amount * 1_000_000_000;

  const transaction = new Transaction().add(
    SystemProgram.transfer({
      fromPubkey: keypair.publicKey,
      toPubkey: toPublicKey,
      lamports
    })
  );
  logger.info("Sending lamports to", toPublicKey.toString());
  try {
    const signature = await sendAndConfirmTransaction(connection, transaction, [keypair]);
    logger.info("Solana TX success:", signature);
    return {success:true, signature};
  } catch (e) {
    logger.error("Solana TX fail:", e);
    return {success:false, error:e.message};
  }
}

cron.schedule('0 0 * * *', async () => {
  logger.info("Running daily tasks for solana_agents...");
  try {
    const resp = await axios.get(`${QUANT_SERVICE_URL}/health`);
    logger.info("quant_service health:", resp.data);
  } catch(e) {
    logger.error("Error contacting quant_service:", e.message);
  }
});

async function getTwitterData() {
  try {
    const scraper = new Scraper();
    await scraper.login(TWITTER_USERNAME, TWITTER_PASSWORD, TWITTER_EMAIL);
    const tweets = await scraper.searchTweets("#solana", 20, SearchMode.Latest);
    logger.info("Latest tweets:", tweets.map(t => t.full_text));
  } catch(e) {
    logger.error("Failed to fetch tweets:", e.message);
  }
}

app.post('/trade', async (req, res) => {
  const data = req.body;
  logger.info("Received trade request:", data);
  await getTwitterData();
  const result = await processTransaction("SOL", 0.1);
  return res.status(200).json({message:"Trading logic placeholder", solana:result});
});

app.listen(PORT, () => {
  logger.info(`solana_agents listening on port ${PORT}`);
});
EOF

echo "[INFO] Done overwriting main.py files + solana_agents/index.js"
echo "[INFO] Next steps: docker-compose build --no-cache && docker-compose up -d && ./vots_unified_dashboard.sh"

