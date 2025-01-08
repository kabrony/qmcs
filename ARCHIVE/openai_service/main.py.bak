import os
from dotenv import load_dotenv
from typing import Optional, List, Dict
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
from langchain_openai import OpenAIEmbeddings
from langchain_chroma import Chroma
from langchain.text_splitter import CharacterTextSplitter
from langchain_core.documents import Document
import asyncio
from datetime import datetime
import openai
load_dotenv(
app = FastAPI(
    title="OpenAI Service w/ Advanced Memory",
    version="1.0.0",


def choose_model_based_on_complexity(prompt: str) -> str:
    # Simple logic - adapt as needed
    if "complex" in prompt.lower() or "reasoning" in prompt.lower():
        return "gpt-4o"
    elif "code" in prompt.lower():
        return "gpt-4o"
    else:
        return "gpt-3.5-turbo"

embeddings = OpenAIEmbeddings(disallowed_special=(
vectorstore = Chroma(
    collection_name="my_longterm_memory",
    embedding_function=embeddings,
    persist_directory="/app/chroma_storage"

class AddDocRequest(BaseModel):
    text: str
    chunk_size: int = 200
    chunk_overlap: int = 20

class AskRequest(BaseModel):
    query: str
    k: Optional[int] = 3

@app.post("/add_doc"
async def add_doc(req: AddDocRequest):
    try:
        splitter = CharacterTextSplitter(
            separator=" ",
            chunk_size=req.chunk_size,
            chunk_overlap=req.chunk_overlap
        chunks = splitter.split_text(req.text
        docs = [Document(page_content=chunk) for chunk in chunks]
        vectorstore.add_documents(docs
        return {"message": f"Stored {len(chunks)} chunks.", "chunks": chunks}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e

@app.post("/ask"
async def ask(req: AskRequest):
    try:
        relevant_docs = vectorstore.similarity_search(req.query, k=req.k or 3
        combined_text = "\n".join([doc.page_content for doc in relevant_docs]

        system_prompt = (
            "You are an AI assistant with knowledge from these docs:\n"
            f"{combined_text}\n\n"
            "Answer based on these docs. If not found, say unsure."
        chosen_model = choose_model_based_on_complexity(req.query
        client = openai.Client(api_key=os.getenv("OPENAI_API_KEY"
        response = await client.chat.completions.create(
            model=chosen_model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": req.query}
            ],
            temperature=0.7,
        if response.choices[0].message is None:
          return {"answer": None, "chosen_model": chosen_model,"docsUsed": [d.page_content for d in relevant_docs]}
        answer = response.choices[0].message.content.strip(
        return {"answer": answer, "chosen_model": chosen_model, "docsUsed": [d.page_content for d in relevant_docs]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e

@app.get("/models"
async def list_models():
    return {
        "data": [
            {"id": "gpt-4o"},
            {"id": "gpt-3.5-turbo"},
            {"id": "o1"},
            {"id": "o1-mini"}
        ]

@app.post("/chat"
async def chat_endpoint(payload: Dict):
    try:
        user_message = payload.get("messages", [{"role": "user","content":""}])[-1]["content"]
        chosen_model = choose_model_based_on_complexity(user_message
        client = openai.Client(api_key=os.getenv("OPENAI_API_KEY"
        response = await client.chat.completions.create(
            model=chosen_model,
            messages=[{"role": "user", "content": user_message}],
            temperature=0.7,
        if response.choices[0].message is None:
          return {"model_used": chosen_model, "answer": None}
        answer = response.choices[0].message.content.strip(
        return {"model_used": chosen_model, "answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e

@app.get("/health"
async def health():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}














