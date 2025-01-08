import os
import json
import weaviate
import httpx
from fastapi import FastAPI, HTTPException
from typing import List
from pydantic import ValidationError
from dotenv import load_dotenv
from utils.app.utils import setup_logger, ResearchIdea, BaseSettings, format_log_message

load_dotenv()
logger = setup_logger(__name__)
app = FastAPI()

class Settings(BaseSettings):
    weaviate_url: str = os.getenv("WEAVIATE_URL")
    weaviate_api_key: str = os.getenv("WEAVIATE_API_KEY")

settings = Settings()

WEAVIATE_CLASS_NAME = "ResearchIdeas"

@app.get("/health")
async def health():
    return {"message": "knowledge_service healthy"}

def get_weaviate_client():
    if not settings.weaviate_url or not settings.weaviate_api_key:
        logger.error(format_log_message("ERROR", "Missing weaviate config."))
        raise HTTPException(status_code=500, detail="Weaviate config missing.")
    client = weaviate.Client(
        url=settings.weaviate_url,
        additional_headers={"X-OpenAI-Api-Key": settings.weaviate_api_key}
    )
    return client

@app.on_event("startup")
async def startup_event():
    try:
        client = get_weaviate_client()
        schema = client.schema.get()
        class_names = [c["class"] for c in schema.get("classes", [])]
        if WEAVIATE_CLASS_NAME not in class_names:
            new_class = {
                "class": WEAVIATE_CLASS_NAME,
                "vectorizer": "text2vec-openai",
                "properties":[
                   {"name": "area", "dataType": ["text"]},
                   {"name": "content", "dataType": ["text"]},
                   {"name": "score", "dataType": ["int"]},
                   {"name": "related_urls", "dataType": ["text"]},
                ]
            }
            client.schema.create_class(new_class)
            logger.info(format_log_message("INFO", f"Created class {WEAVIATE_CLASS_NAME}"))
    except Exception as e:
        logger.error(format_log_message("ERROR", f"Could not verify or create class: {e}"))
        raise e

@app.post("/store_idea/")
def store_idea(idea: ResearchIdea):
    try:
        client = get_weaviate_client()
        data_object = idea.dict()
        response = client.data_object.create(
            data_object,
            class_name=WEAVIATE_CLASS_NAME
        )
        return idea
    except Exception as e:
        logger.error(format_log_message("ERROR", f"Failed to store idea: {e}", context={"idea": idea.dict()}))
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/search_ideas/", response_model=List[ResearchIdea])
def search_ideas(query:str, limit:int=10):
    try:
        client = get_weaviate_client()
        nearText = {"concepts":[query]}
        result = (
            client.query
            .get(WEAVIATE_CLASS_NAME, ["area","content","score","related_urls"])
            .with_near_text(nearText)
            .with_limit(limit)
            .do()
        )
        out = []
        if result.get("data") and result["data"].get("Get") and result["data"]["Get"].get(WEAVIATE_CLASS_NAME):
            for obj in result["data"]["Get"][WEAVIATE_CLASS_NAME]:
                try:
                    out.append(ResearchIdea(
                        area=obj["area"],
                        content=obj["content"],
                        score=obj["score"],
                        related_urls=obj["related_urls"]
                    ))
                except ValidationError as ve:
                    logger.error(format_log_message("ERROR", f"Validation error when processing search result: {ve}", context={"object": obj}))
        return out
    except Exception as e:
        logger.error(format_log_message("ERROR", f"Failed to search: {e}", context={"query": query, "limit": limit}))
        raise HTTPException(status_code=500, detail=str(e))
