#!/usr/bin/env python3

import os
import logging

# Import from google-genai
import google.genai as genai
from google.genai import types
from google.genai.errors import ClientError

logging.basicConfig(level=logging.INFO)

def main():
    # Grab your API key from environment
    api_key = os.getenv("GEMINI_API_KEY", "")
    if not api_key:
        logging.error("No GEMINI_API_KEY set. Please export your API key.")
        return

    # Configure the GenAI client
    genai.configure(api_key=api_key)
    
    # Create a client object
    client = genai.Client(api_key=api_key)

    prompt_text = "Hello from google-genai in final_advanced_demo!"
    try:
        # Attempt text generation
        response = client.models.generate_content(
            model="gemini-pro",  # or "gemini-1.5-flash", etc.
            contents=prompt_text,
            config=types.GenerateContentConfig(temperature=0.2),
        )
        logging.info(f"LLM Response: {response.text}")
    except ClientError as e:
        logging.error(f"ClientError: {e}")
    except Exception as ex:
        logging.error(f"Unexpected error: {ex}")

if __name__ == "__main__":
    main()

