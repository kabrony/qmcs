from fastapi import FastAPI, HTTPException
from typing import List
import os
import httpx
import json
import asyncio
import logging
from playwright.async_api import async_playwright
from dotenv import load_dotenv
from pydantic import ValidationError

from utils.app.utils import (
    setup_logger, TargetWebsite, ResearchIdea, ResearchTask, LLMResponse,
    BaseSettings, format_log_message, HistoryStep
)
from .langchain_openai import OpenAIHelper
from .browser_use import Agent

load_dotenv()

logger = setup_logger(__name__)
app = FastAPI()

class Settings(BaseSettings):
    openai_api_key: str = os.getenv("OPENAI_API_KEY")
    knowledge_service_url: str = os.getenv("KNOWLEDGE_SERVICE_URL")

settings = Settings()

class NetworkClient:
    def __init__(self):
        self.client = httpx.AsyncClient()

    async def post(self, url: str, json: dict, retries=3, delay=1):
        for attempt in range(retries):
            try:
                response = await self.client.post(url, json=json, timeout=10)
                response.raise_for_status()
                return response.json()
            except httpx.HTTPStatusError as e:
                logger.warning(format_log_message("WARNING", f"HTTP Error: {e}. Retrying in {delay} seconds.", context={"url": url, "attempt": attempt + 1, "retries": retries}))
                if attempt < retries - 1:
                    await asyncio.sleep(delay)
                    delay *= 2
                else:
                    logger.error(format_log_message("ERROR", f"Failed POST request after {retries} retries.", context={"url": url}))
                    raise
            except httpx.TransportError as e:
                logger.warning(format_log_message("WARNING", f"Network error during POST to {url}: {e}. Retrying in {delay} seconds.", context={"attempt": attempt + 1, "retries": retries}))
                if attempt < retries - 1:
                    await asyncio.sleep(delay)
                    delay *= 2
                else:
                    logger.error(format_log_message("ERROR", f"Failed POST request after {retries} retries due to network error.", context={"url": url}))
                    raise
            except Exception as e:
                logger.error(format_log_message("ERROR", f"Unexpected error during POST to {url}: {e}", context={"url": url}))
                raise
        return None

network_client = NetworkClient()
llm_helper = OpenAIHelper(openai_api_key=settings.openai_api_key)

@app.get("/health")
async def health():
    return {"message": "browser_service healthy"}

@app.post("/run_task/")
async def run_task(research_task: ResearchTask):
    try:
        if not settings.knowledge_service_url:
            raise Exception("KNOWLEDGE_SERVICE_URL not set")

        if research_task.task_type == "daily_research":
            websites = [
                TargetWebsite(url="https://www.example.com", category="architecture"),
                TargetWebsite(url="https://www.example.net", category="circuits"),
                TargetWebsite(url="https://www.example.org", category="quant"),
            ]
            all_ideas = []
            for w in websites:
                ideas = await research_website(w.url, research_task.research_areas)
                all_ideas.extend(ideas)
            return {"ideas": all_ideas}

        elif research_task.task_type == "website_exploration" and research_task.website:
            ideas = await research_website(research_task.website, research_task.research_areas)
            return {"ideas": ideas}
        else:
            raise HTTPException(status_code=400, detail="Invalid research_task parameters")

    except Exception as e:
        logger.error(format_log_message("ERROR", f"Failed to run task: {e}", context={"task_type": research_task.task_type}))
        raise HTTPException(status_code=500, detail=f"Failed to run task: {e}")

async def extract_content(url: str) -> str:
    try:
        async with async_playwright() as p:
            browser = await p.chromium.launch()
            page = await browser.new_page()
            await page.goto(url, timeout=60000)
            content = await page.content()
            await browser.close()
            return content
    except Exception as e:
        logger.error(format_log_message("ERROR", f"Failed to extract content from {url}: {e}"))
        return ""

async def research_website(website_url: str, research_areas: List[str]):
    content = await extract_content(website_url)
    if not content:
        logger.warning(format_log_message("WARNING", f"No content extracted from {website_url}"))
        return []

    prompt = (
        f"Analyze the following content for insights related to {', '.join(research_areas)}:\\n\\n"
        f"{content[:8000]}\\n\\n"
        "Generate 2 relevant improvement ideas, each with a short summary, a numeric score (1-10), "
        "and an array of relevant URLs. Return as JSON."
    )

    llm_response = await llm_helper.invoke(prompt)
    if not llm_response or not llm_response.content:
        logger.warning(format_log_message("WARNING", f"LLM did not return any content for {website_url}"))
        return []

    try:
        parsed = json.loads(llm_response.content)
        ideas_list = []
        for item in parsed:
            idea = ResearchIdea(**item)
            await store_idea(idea)
            ideas_list.append(idea.dict())
        return ideas_list
    except (json.JSONDecodeError, ValidationError) as e:
        logger.error(format_log_message("ERROR", f"Could not parse LLM response: {llm_response.content}. Error: {e}"))
        return []

async def store_idea(idea: ResearchIdea):
    if not settings.knowledge_service_url:
        logger.error(format_log_message("ERROR", "No knowledge service URL set"))
        return
    try:
        await network_client.post(f"{settings.knowledge_service_url}/store_idea/", json=idea.dict())
    except Exception as e:
        logger.error(format_log_message("ERROR", f"Failed to store idea to knowledge service: {e}", context={"idea": idea.dict()}))
