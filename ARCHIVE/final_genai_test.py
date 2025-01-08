#!/usr/bin/env python3
import sys
import os
import logging

# 1) If you're using the "google-genai" library v0.3.x or later, 
#    the preferred usage is via "client.models.generate_content(...)"

# 2) Make sure your script is running inside the virtual environment 
#    that has google-genai installed, or fix the shebang to point 
#    directly to the venv python.

# Minimal code that uses google-genai's "Client" and "models.generate_content":

try:
    import google.genai as genai
    from google.genai import types

    logging.basicConfig(level=logging.INFO)

    # If you have your API key in an env var:
    api_key = os.getenv("GEMINI_API_KEY", "PUT_SOMETHING_OR_FAIL")

    logging.info(f"Using API key: {api_key[:6]}... (redacted)")

    # Create the GenAI client
    client = genai.Client(api_key=api_key)

    # Prepare a minimal prompt
    prompt_text = "Hello from a minimal google-genai test!"

    # Attempt generation using the new 'generate_content' method
    response = client.models.generate_content(
        model="gemini-1.5-flash",         # Or whichever model is valid for your key
        contents=prompt_text,
        config=types.GenerateContentConfig(
            temperature=0.2
        ),
    )

    logging.info(f"Response text: {response.text}")
    logging.info("Success: google.genai import and usage worked!")

except ImportError as ie:
    logging.error(f"ImportError: {ie}")
except Exception as ex:
    logging.error(f"Error using google-genai: {ex}")

