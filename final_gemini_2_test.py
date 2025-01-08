#!/usr/bin/env python3

import os
import logging
from google import genai
from google.genai import types
from google.genai.errors import ClientError

logging.basicConfig(level=logging.INFO)

def main():
    # 1) Read your valid Generative Language API key from environment:
    api_key = os.getenv("GEMINI_API_KEY", "")
    if not api_key:
        logging.error("No GEMINI_API_KEY set. Please export a valid Generative Language API key.")
        return

    logging.info(f"Using API key: {api_key[:6]}... (redacted)")

    # 2) Create a GenAI client:
    client = genai.Client(api_key=api_key)

    # 3) Attempt a minimal prompt with gemini-pro:
    try:
        prompt_text = "Hello from Gemini Pro test!"
        response = client.models.generate_content(
            model="gemini-pro",   # <------- Changed to gemini-pro
            contents=prompt_text,
            config=types.GenerateContentConfig(temperature=0.2),
        )
        logging.info(f"Response text: {response.text}")
        logging.info("Success: google.genai import and usage worked with gemini-pro!")
    except ClientError as ce:
        logging.error(f"ClientError: {ce}")
    except Exception as ex:
        logging.error(f"Unexpected error: {ex}")

if __name__ == "__main__":
    main()
