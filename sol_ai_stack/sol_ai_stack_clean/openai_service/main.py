from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"message": "OpenAI Service (auto-named)"}
