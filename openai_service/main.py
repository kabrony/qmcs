import os
import openai
from typing import Optional

import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI
from pydantic import BaseModel

# For advanced memory
from langchain.text_splitter import CharacterTextSplitter
from langchain_openai import OpenAIEmbeddings
from langchain_chroma import Chroma
from langchain.docstore.document import Document

###############################################################################
# 1) ENV & OPENAI
###############################################################################
load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")
if not openai.api_key:
    raise ValueError("Missing OPENAI_API_KEY in environment or .env file!")

###############################################################################
# 2) CREATE EMBEDDINGS + CHROMA STORE
###############################################################################
embeddings = OpenAIEmbeddings(disallowed_special=())
vectorstore = Chroma(
    collection_name="my_longterm_memory",
    embedding_function=embeddings,
    persist_directory="/app/chroma_storage",  # data path in container
)

###############################################################################
# 3) MODEL REQUEST CLASSES
###############################################################################
class AddDocRequest(BaseModel):
    text: str
    chunk_size: int = 200
    chunk_overlap: int = 20

class AskRequest(BaseModel):
    query: str
    k: Optional[int] = 3  # optionally allow a custom number of retrieved docs

###############################################################################
# 4) (OPTIONAL) DYNAMIC MODEL SELECTION
###############################################################################
def choose_model_based_on_complexity(user_prompt: str) -> str:
    """
    Very naive logic:
      - If user prompt includes 'multi-step' => pick 'o1' (the reasoning model)
      - If prompt is quite large => pick 'gpt-4o'
      - Otherwise pick 'gpt-4o-mini'
    """
    length = len(user_prompt)
    lower_prompt = user_prompt.lower()

    if "multi-step" in lower_prompt:
        return "o1"
    elif length > 3000:
        return "gpt-4o"
    else:
        return "gpt-4o-mini"

###############################################################################
# 5) SETUP FASTAPI
###############################################################################
app = FastAPI(
    title="OpenAI Service w/ Advanced Memory",
    description="Stores doc embeddings in Chroma + uses openai.chat.completions.",
    version="1.0.0",
)

@app.post("/add_doc")
def add_doc(req: AddDocRequest):
    """
    Splits req.text into chunks, embeds them, stores them in Chroma.
    """
    splitter = CharacterTextSplitter(
        separator=" ",
        chunk_size=req.chunk_size,
        chunk_overlap=req.chunk_overlap
    )
    chunks = splitter.split_text(req.text)
    docs = [Document(page_content=chunk) for chunk in chunks]

    vectorstore.add_documents(docs)
    return {
        "message": f"Stored {len(chunks)} chunk(s) in the vector store.",
        "chunks": chunks
    }

@app.post("/ask")
def ask(req: AskRequest):
    """
    Retrieve top relevant docs from Chroma + call openai.chat.completions.
    Example request JSON: {"query":"What is Solana?"}
    """
    # Retrieve relevant docs
    relevant_docs = vectorstore.similarity_search(req.query, k=req.k or 3)
    combined_text = "\n".join([doc.page_content for doc in relevant_docs])

    # Build the system prompt from those docs
    system_prompt = (
        "You are an AI assistant with knowledge from these docs:\n"
        f"{combined_text}\n\n"
        "Answer the user's question based on these docs. "
        "If you don't find relevant info, say you are unsure."
    )

    try:
        chosen_model = choose_model_based_on_complexity(req.query)  # optional
        response = openai.chat.completions.create(
            model=chosen_model,  # e.g. "gpt-4o", "gpt-4o-mini", "o1", etc.
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user",   "content": req.query}
            ],
            temperature=0.7,
        )
        answer = response.choices[0].message.content.strip()
        return {
            "answer": answer,
            "chosen_model": chosen_model,
            "docsUsed": [d.page_content for d in relevant_docs]
        }
    except Exception as e:
        return {"error": str(e)}

@app.get("/health")
def health():
    return {"status": "ok"}

###############################################################################
# 6) LAUNCH
###############################################################################
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=5000, reload=False)
