import unittest
import asyncio
import os
import httpx
import json
from unittest.mock import patch

from utils.app.utils import (
    TargetWebsite, ResearchIdea, ResearchTask, BaseSettings,
    format_log_message, HistoryStep, LLMResponse
)

class TestSettings(BaseSettings):
    OPENAI_API_KEY: str = "dummy_key"
    WEAVIATE_URL: str = "http://dummy_url"
    WEAVIATE_API_KEY: str = "dummy_key"
    KNOWLEDGE_SERVICE_URL: str = "http://test_knowledge:8001"

test_settings = TestSettings()

class MockResponse:
    def __init__(self, json_data, status_code=200):
        self._json_data = json_data
        self.status_code = status_code

    def json(self):
        return self._json_data

    def raise_for_status(self):
        if self.status_code >= 400:
            raise httpx.HTTPError("Error")

class MockAsyncClient:
    def __init__(self):
        self.post_calls = []
        self.get_calls = []

    async def post(self, url: str, json: dict, headers=None, timeout=10):
        self.post_calls.append((url, json, headers, timeout))
        return MockResponse(json_data={"id": "test-id", **json})

    async def get(self, url: str, params=None, headers=None, timeout=10):
        self.get_calls.append((url, params, headers, timeout))
        if "search" in url:
            return MockResponse(
                json_data={"data": {"Get": {
                    "ResearchIdeas": [
                        {"area": "quant", "content": "test_idea_1", "score": 5, "related_urls": []},
                        {"area": "circuits", "content": "test_idea_2", "score": 3, "related_urls": ["https://test.com"]}
                    ]
                }}}
            )
        else:
            return MockResponse(json_data={"id": "test-id", "area": "test", "content": "test",
                                           "score": 4, "related_urls": ["http://example.com"]})

class TestServices(unittest.IsolatedAsyncioTestCase):

    async def test_store_idea(self):
        from knowledge_service.app.main import store_idea, get_weaviate_client
        from fastapi import Depends

        idea = ResearchIdea(area="test", content="test", score=4, related_urls=["http://example.com"])

        async def mock_get_weaviate_client():
            class MockWeaviateClient:
                class MockDataObject:
                    def create(self, data_object, class_name):
                        return data_object
                data_object = MockDataObject()
            return MockWeaviateClient()

        with patch("knowledge_service.app.main.get_weaviate_client", mock_get_weaviate_client):
            result = store_idea(idea)
            self.assertEqual(result.area, "test")

    async def test_search_ideas(self):
        from knowledge_service.app.main import search_ideas, get_weaviate_client

        async def mock_get_weaviate_client():
            class MockWeaviateClient:
                def __init__(self):
                    pass
                class MockQuery:
                    class MockGet:
                        def with_near_text(self, nearText):
                            return self
                        def with_limit(self, limit):
                            return self
                        def do(self):
                            return {"data": {"Get": {"ResearchIdeas": [
                                {"area": "quant", "content": "test_idea_1", "score": 5, "related_urls": []},
                                {"area": "circuits", "content": "test_idea_2", "score": 3, "related_urls": ["https://test.com"]}
                            ]}}}
                    def get(self, class_name, fields):
                        return self.MockGet()
                def query(self):
                    return self.MockQuery()
            return MockWeaviateClient()

        with patch("knowledge_service.app.main.get_weaviate_client", mock_get_weaviate_client):
            ideas = search_ideas("test", 10)
            self.assertEqual(len(ideas), 2)

    async def test_run_task_daily_research(self):
        from browser_service.app.main import run_task, extract_content
        from browser_service.app.langchain_openai import OpenAIHelper

        async def mock_extract_content(url: str) -> str:
            return f"Content from {url}"

        async def mock_store_idea(idea: ResearchIdea):
            pass

        class MockOpenAIHelper:
            async def invoke(self, prompt):
                # Return 2 ideas for each website
                return LLMResponse(content=json.dumps([
                    {"area": "test", "content": "idea1", "score": 7, "related_urls": ["http://example.com"]},
                    {"area": "test", "content": "idea2", "score": 8, "related_urls": ["http://example.net"]}
                ]))

        with patch("browser_service.app.main.extract_content", mock_extract_content):
            with patch("browser_service.app.main.store_idea", mock_store_idea):
                with patch("browser_service.app.main.OpenAIHelper", return_value=MockOpenAIHelper()):
                    task = ResearchTask(task_type="daily_research", research_areas=["test"])
                    results = await run_task(task)
                    # 3 websites * 2 ideas each => 6
                    self.assertEqual(len(results["ideas"]), 6)

    async def test_run_task_website_exploration(self):
        from browser_service.app.main import run_task, extract_content
        from browser_service.app.langchain_openai import OpenAIHelper

        async def mock_extract_content(url: str) -> str:
            return f"Content from {url}"

        async def mock_store_idea(idea: ResearchIdea):
            pass

        class MockOpenAIHelper:
            async def invoke(self, prompt):
                return LLMResponse(content=json.dumps([
                    {"area": "test", "content": "idea1", "score": 7, "related_urls": ["http://example.com"]},
                    {"area": "test", "content": "idea2", "score": 8, "related_urls": ["http://example.net"]}
                ]))

        with patch("browser_service.app.main.extract_content", mock_extract_content):
            with patch("browser_service.app.main.store_idea", mock_store_idea):
                with patch("browser_service.app.main.OpenAIHelper", return_value=MockOpenAIHelper()):
                    task = ResearchTask(task_type="website_exploration", research_areas=["test"], website="http://test.com")
                    results = await run_task(task)
                    self.assertEqual(len(results["ideas"]), 2)

if __name__ == "__main__":
    unittest.main()
