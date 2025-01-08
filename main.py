from fastapi import FastAPI
from langchain.text_splitter import CharacterTextSplitter

app = FastAPI()

@app.get("/")
def read_root():
    splitter = CharacterTextSplitter(chunk_size=100, chunk_overlap=10)
    chunks = splitter.split_text("Hello, World!")
    return {"chunks": chunks}
