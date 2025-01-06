#!/usr/bin/env python3

"""
solana_ai_trader.py (Meme Coin Quick-Trader)
--------------------------------------------
- Reads environment variables:
  OPENAI_API_KEY, GEMINI_API_KEY, TAVILY_API_KEY (optional),
  MONGO_DETAILS, SOLANA_RPC_URL, SOLANA_PUBLIC_KEY, SOLANA_PRIVATE_KEY
- Analyzes short-term pump potential of Solana meme coins using:
  1) On-chain Whale/Dev wallet data (provided by 'quant_service' or aggregator).
  2) Social hype sentiment (AI assisted).
  3) Basic volume stats from a DEX aggregator if desired.
- Decides whether to buy or hold for a quick pump, then sets a stop-loss & take-profit.

DEPENDENCIES:
  pip install --no-cache-dir python-dotenv pymongo openai google-generativeai tavily-python solana tenacity requests

IMPORTANT NOTES:
  - This script is a starting point. For a working pipeline, you'll also need:
    (a) A small 'quant_service' that returns on-chain stats / whale signals.
    (b) A method to sign & send Solana transactions if you want real trades
        (see 'solana_agents' or node-based transaction calls).
  - The logic below is simplified, focusing on analyzing signals and deciding.
  - Once we commit to a buy, we'd call an external service (e.g. 'solana_agents')
    to execute the trade on a Solana DEX aggregator route.
"""

import os
import sys
import time
import logging
import requests
import openai

client = openai.OpenAI(api_key=OPENAI_API_KEY)
import google.generativeai as genai
from dotenv import load_dotenv
from pymongo import MongoClient, errors
from tenacity import retry, stop_after_attempt, wait_fixed

######################
# BASIC CONFIG & INIT
######################
load_dotenv()
logging.basicConfig(level=logging.INFO)

OPENAI_API_KEY   = os.getenv("OPENAI_API_KEY")
GEMINI_API_KEY   = os.getenv("GEMINI_API_KEY")
TAVILY_API_KEY   = os.getenv("TAVILY_API_KEY")   # optional
MONGO_DETAILS    = os.getenv("MONGO_DETAILS")
SOLANA_RPC_URL   = os.getenv("SOLANA_RPC_URL")
SOLANA_PUBLIC_KEY= os.getenv("SOLANA_PUBLIC_KEY")
SOLANA_PRIVATE_KEY= os.getenv("SOLANA_PRIVATE_KEY")  # optional if we sign trades
OPENAI_MODEL_NAME= os.getenv("OPENAI_MODEL_NAME", "gpt-3.5-turbo")

if not (OPENAI_API_KEY and GEMINI_API_KEY and MONGO_DETAILS and SOLANA_PUBLIC_KEY):
    logging.error("Missing env: OPENAI_API_KEY, GEMINI_API_KEY, MONGO_DETAILS, SOLANA_PUBLIC_KEY.")
    sys.exit(1)

# AI setups
genai.configure(api_key=GEMINI_API_KEY)
tavily_client = None
if TAVILY_API_KEY:
    try:
        from tavily import TavilyClient
        tavily_client = TavilyClient(api_key=TAVILY_API_KEY)
    except ImportError:
        logging.warning("Tavily library not found or error loading. Proceeding without Tavily...")

# Connect to Mongo (for ephemeral logs or chain-of-thought)
try:
    mclient = MongoClient(MONGO_DETAILS)
    mclient.admin.command("ping")
    logging.info("Connected to Mongo for AI Trader logs.")
except errors.ConnectionFailure as e:
    logging.error(f"Mongo connect fail: {e}")
    sys.exit(1)

########################
# Helper: Log Thought
########################
def log_thought(step: str, content: str):
    """Stores ephemeral reasoning steps in Mongo ephemeral_memory.chain_of_thought."""
    try:
        with MongoClient(MONGO_DETAILS) as mc:
            db = mc["ephemeral_memory"]
            db["chain_of_thought"].insert_one({
                "step": step,
                "content": content,
                "timestamp": time.time()
            })
            logging.info(f"Logged step: {step}")
    except Exception as e:
        logging.error(f"Log thought error: {e}")

########################
# AI Calls
########################
@retry(stop=stop_after_attempt(3), wait=wait_fixed(2))
def call_openai(prompt: str) -> str:
    """Uses GPT model to interpret hype or do sentiment analysis."""
    try:
        resp = client.chat.completions.create(model=OPENAI_MODEL_NAME,
        messages=[
            {"role": "system", "content": "You are a Solana meme coin pump trading assistant."},
            {"role": "user",   "content": prompt}
        ],
        max_tokens=250,
        temperature=0.8)
        return resp.choices[0].message.content
    except Exception as e:
        msg = f"[OpenAI error: {e}]"
        logging.error(msg)
        return msg

@retry(stop=stop_after_attempt(3), wait=wait_fixed(2))
def call_gemini(prompt: str) -> str:
    """Calls Google Gemini for additional sentiment or analysis."""
    try:
        model = genai.GenerativeModel("gemini-pro")
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        msg = f"[Gemini error: {e}]"
        logging.error(msg)
        return msg

@retry(stop=stop_after_attempt(3), wait=wait_fixed(2))
def call_tavily(prompt: str) -> str:
    """Optional Tavily usage."""
    if not tavily_client:
        return "[Tavily not configured]"
    try:
        out = tavily_client.search(prompt)
        return f"Tavily => {out.get('results', [])}"
    except Exception as e:
        msg = f"[Tavily error: {e}]"
        logging.error(msg)
        return msg

########################
# Example "quant_service" Call
########################
def fetch_pump_signals(token:str) -> dict:
    """
    Placeholder: calls a hypothetical /pump-signals endpoint from 'quant_service' 
    or aggregator to get:
     - dev_whale_activity: 0..1
     - social_score: 0..1
     - volume_score: 0..1
    Returns a dictionary, we combine to produce a 'pump_score'.
    """
    try:
        # e.g. requests.get('http://quant-service:7000/pump-signals?token='+token)
        # For now, just random placeholders:
        dev_whale_activity = 0.5  # example
        social_score = 0.6
        volume_score = 0.4
        return {
            "dev_whale_activity": dev_whale_activity,
            "social_score": social_score,
            "volume_score": volume_score
        }
    except Exception as e:
        logging.error(f"Error fetching pump signals: {e}")
        return {}

########################
# Main Trading Logic
########################
def analyze_token(token: str) -> float:
    """
    Gather signals from quant_service + AI for the token.
    Returns a final pump_score from 0..100, or -1 if error.
    """
    # Step1: fetch data from quant_service
    signals = fetch_pump_signals(token)
    dev_whale = signals.get("dev_whale_activity", 0)
    social    = signals.get("social_score", 0)
    volume    = signals.get("volume_score", 0)

    # Step2: AI sentiment call
    openai_ans = call_openai(f"Token {token}: short-term hype? Rate 1..10. Provide quick reasoning.")
    gemini_ans = call_gemini(f"Token {token} social mention analysis. Is it spiking in next 6hrs?")

    log_thought(f"{token}_openai", openai_ans)
    log_thought(f"{token}_gemini", gemini_ans)

    # naive parse of rating from openai's text
    # (In reality we'd do more robust extraction)
    ai_score = 0.5
    if "8" in openai_ans or "9" in openai_ans or "10" in openai_ans:
        ai_score = 1.0
    elif "6" in openai_ans or "7" in openai_ans:
        ai_score = 0.7

    # Weighted formula
    combined = (dev_whale * 0.3) + (social * 0.3) + (volume * 0.2) + (ai_score * 0.2)
    pump_score = combined * 100

    log_thought(f"{token}_pump_score", f"{pump_score:.2f}")
    return pump_score

def decide_buy_sell(token: str, pump_score: float):
    """
    If pump_score > some threshold (e.g. 70), we 'buy' for quick flip.
    For demonstration only. In reality, you'd call 'solana_agents' to execute.
    """
    if pump_score < 0:
        logging.error("No valid pump_score. Skipping.")
        return

    if pump_score >= 70:
        logging.info(f"[{token}] Score={pump_score:.2f} => BUY signal.")
        # Here we'd do a call to solana_agents to sign & send transaction
        # e.g. requests.post('http://solana_agents:4000/doBuy', json={"token": token, "amount": 30})
        log_thought(f"{token}_decision", "BUY triggered!")
    else:
        logging.info(f"[{token}] Score={pump_score:.2f} => NO buy.")
        log_thought(f"{token}_decision", "No buy, insufficient hype.")

########################
# MAIN
########################
def main():
    # Example tokens to analyze, in practice we'd fetch from aggregator or user input
    meme_tokens = ["BONK", "DOGGOSOL", "FAKEPUMP"]

    for token in meme_tokens:
        pscore = analyze_token(token)
        decide_buy_sell(token, pscore)

if __name__ == "__main__":
    main()
