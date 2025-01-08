import openai
import openai

client = openai.OpenAI(api_key=openai_api_key or os.getenv("OPENAI_API_KEY"))
import logging
import asyncio
import os
from utils.app.utils import LLMResponse

logger = logging.getLogger(__name__)

class OpenAIHelper:
    def __init__(self, model="gpt-3.5-turbo", openai_api_key=None):
        self.model = model
        if not openai.api_key:
            logger.error("OPENAI_API_KEY is not set.")

    async def invoke(self, prompt, retries=3, delay=1):
        for attempt in range(retries):
            try:
                response = client.chat.completions.create(model=self.model,
                messages=[{"role": "user", "content": prompt}])
                return LLMResponse(content=response.choices[0].message.content)
            except openai.OpenAIError as e:
                logger.warning(f"OpenAI API error: {e}. Attempt {attempt + 1}/{retries}. Retrying in {delay} seconds.")
                if attempt < retries - 1:
                    await asyncio.sleep(delay)
                    delay *= 2
                else:
                    logger.error(f"OpenAI API failed after {retries} retries.")
                    raise
        return None
