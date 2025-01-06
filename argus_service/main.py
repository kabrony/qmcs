import os
import openai
from dotenv import load_dotenv
from fastapi import FastAPI

load_dotenv()  # loads .env

# We'll set openai.api_key explicitly for openai>=1.0
openai.api_key = os.getenv("OPENAI_API_KEY")

app = FastAPI()

@app.get("/")
async def root():
    return {"service": "argus_service", "status": "OK"}

@app.get("/test_openai")
async def test_openai():
    """
    Minimal usage for openai>=1.0:
    Using ChatCompletion endpoint with GPT-3.5.
    """
    try:
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[{"role":"user","content": "Say hello from the new library."}],
            temperature=0.7,
        )
        msg = response.choices[0].message.content.strip()
        return {"response": msg}
    except Exception as e:
        return {"error": str(e)}
