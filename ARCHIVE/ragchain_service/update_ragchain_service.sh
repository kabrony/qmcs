#!/bin/bash

# Navigate to the project directory (assuming the script is in the root)
cd ""

cat << EOF > ragchain_service/main.py
import os
from fastapi import FastAPI, HTTPException
from motor.motor_asyncio import AsyncIOMotorClient
from tenacity import retry, stop_after_attempt, wait_fixed
import asyncio
from datetime import datetime
from dotenv import load_dotenv
from langchain_openai import OpenAIEmbeddings
from langchain_chroma import Chroma
from langchain_text_splitters import CharacterTextSplitter
from langchain_core.documents import Document
import openai
import uvicorn
import logging
from fastapi import FastAPI
import google.generativeai as genai

load_dotenv()
app = FastAPI()

MONGO_URL = os.getenv("MONGO_URL","mongodb://mongo:27017")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
db_client = None
ephemeral_thoughts = []


genai.configure(api_key=GEMINI_API_KEY)

# Model options: "gemini-pro", "gemini-ultra" (if available)
gemini_model = genai.GenerativeModel('gemini-pro')


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
    logging.info(f"[ragchain_service] ping: {result}")

@app.on_event("startup")
async def startup_event():
    await connect_to_mongo()
    logging.info("[ragchain_service] Connected to Mongo (async).")

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
async def ask(query: str, k: int=3, use_gemini: bool = False):
    try:
      if use_gemini:
          response = gemini_model.generate_content(query)
          ans = response.text
          return {"answer": ans, "docsUsed":[]} # No document context with Gemini for now.
      else:
        relevant_docs = vectorstore.similarity_search(query, k=k or 3)
        combined_text = "\n".join([doc.page_content for doc in relevant_docs])
        prompt = (
            "You are an AI with knowledge from docs:\n"
            f"{combined_text}\n\n"
            "Answer user question. If not found, say 'unsure'."
        )
        response = await openai.chat.completions.create(
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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5000)
