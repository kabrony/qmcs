#!/usr/bin/env python3
"""
solana_ai_trader_updated.py
Demonstrates a snippet for calling the new OpenAI ChatCompletion (>=1.0.0).
Replaces old usage that caused "You tried to access openai.ChatCompletion" error.
"""

import os
import sys
import logging
import openai
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO)

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL   = os.getenv("OPENAI_MODEL", "gpt-3.5-turbo")

if not OPENAI_API_KEY:
    logging.error("Missing OPENAI_API_KEY in environment.")
    sys.exit(1)

openai.api_key = OPENAI_API_KEY

def call_openai(prompt: str) -> str:
    """
    Calls OpenAI's ChatCompletion with the new usage (>=1.0.0).
    Returns the text from the first completion choice.
    """
    try:
            model=OPENAI_MODEL,
            messages=[
                {"role": "system", "content": "You are a Solana meme coin pump trading assistant."},
                {"role": "user",   "content": prompt},
            ],
            max_tokens=200,
            temperature=0.8
        )
        # The new library usage is largely the same; just confirm you're on openai>=1.0.0
        return response.choices[0].message.content
    except Exception as e:
        logging.error(f"[OpenAI error: {e}]")
        return f"[Error] {e}"

def main():
    logging.info("Starting updated solana_ai_trader with new OpenAI usage...")

    sample_prompt = "Analyze the hype around $SOL. Is it bullish short term?"
    answer = call_openai(sample_prompt)
    logging.info(f"OpenAI Answer => {answer}")

if __name__ == "__main__":
    main()


# [GPT 1.0.0 snippet] 
# Example usage for openai>=1.0.0:
# def get_openai_response():
#     import openai
#     openai.api_key = "YOUR_KEY"
#     try:
#         # The new usage: pass "model" and "messages"
#         response = openai.chat.completions.create(
#             model="gpt-3.5-turbo",
#             messages=[{"role": "user", "content": "Hello!"}]
#         )
#         print(response.choices[0].message.content)
#     except Exception as e:
#         print(f"[ERROR] openai.chat.completions => {e}")

