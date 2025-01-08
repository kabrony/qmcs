#!/usr/bin/env python3

import os
import sys
import logging
import datetime
import json
import requests
from typing import Any, Dict
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

# google-genai library for Gemini
import google.generativeai as genai
from google.genai.errors import ClientError

DARK_BG = "\\x1b[48;2;30;30;30m"
HIGH_CONTRAST_FG = "\\x1b[38;2;255;255;255m"
RESET_ANSI = "\\x1b[0m"

def dark_print(msg: str, lvl: str = "INFO"):
    ansi_msg = f"{DARK_BG}{HIGH_CONTRAST_FG}{msg}{RESET_ANSI}"
    if lvl == "INFO": logging.info(ansi_msg)
    elif lvl == "WARN": logging.warning(ansi_msg)
    elif lvl == "ERROR": logging.error(ansi_msg)
    else: logging.info(ansi_msg)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

def main():
    dark_print("Starting advanced_solana_zk_demo.py...", "INFO")
    dark_print(f"sys.path: {sys.path}", "INFO")
    
    try:
       dark_print("Attempting to import google.generativeai...", "INFO")
       #genai.configure(api_key=os.environ.get('GOOGLE_API_KEY'))
       #model = genai.GenerativeModel("gemini-1.5-flash") # or "gemini-pro"
       #response = model.generate_content("Can you tell me a joke about Solana ZK?")
       #dark_print(f"LLM Response: {response.text}", "INFO")
       dark_print("Successfully imported google.generativeai (commented out the use for now during debugging)...", "INFO")

    except ModuleNotFoundError as e:
        dark_print(f"ModuleNotFoundError during direct import: {e}", "ERROR")
    except Exception as e:
         dark_print(f"Exception during direct import: {e}", "ERROR")
    
    dark_print("advanced_solana_zk_demo.py finished.", "INFO")

if __name__ == "__main__":
    main()
