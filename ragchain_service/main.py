from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ragchain_service OK"}

@app.get("/")
def root():
    return {"message": "Hello from ragchain_service placeholder."}
