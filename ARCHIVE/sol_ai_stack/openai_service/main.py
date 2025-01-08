import os
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"message": "OpenAI Service is running on port 3001"}

# Placeholder example: you'd integrate your OpenAI logic here
