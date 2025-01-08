from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "quant_service OK"}

@app.get("/")
def root():
    return {"message": "Hello from quant_service placeholder."}
