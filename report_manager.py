#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
report_manager.py

Purpose:
  1) Gather data from solana_agents (on-chain data), ephemeral memory logs (chain-of-thought),
     local trading stats (PnL, trades).
  2) Summarize the system’s status using a chosen LLM (OpenAI, Gemini, or TAVILY).
  3) Demonstrate robust error handling, fallback logic, ephemeral memory usage.

Usage Examples:
  python3 report_manager.py
  # Possibly called once a day or on an interval to produce a "full report."

"""

import os
import sys
import json
import time
import requests

# For ephemeral memory or chain-of-thought:
# If you have Redis or in-memory route, you might do:
# import redis
# r = redis.Redis(host='redis', port=6379, decode_responses=True)

try:
    import openai
    
    client = openai.OpenAI(api_key=OPENAI_KEY)
    # If using Google Gemini or TAVILY, you'd import or define their API calls similarly.
except ImportError:
    print("[ERROR] 'openai' library not installed. Please pip install openai or adapt for Google Gemini/TAVILY.")
    sys.exit(1)

###############################################################################
# CONFIG / ENV VARIABLES
###############################################################################
OPENAI_KEY = os.getenv("OPENAI_API_KEY", "")
GEMINI_KEY = os.getenv("GEMINI_API_KEY", "")
TAVILY_KEY = os.getenv("TAVILY_API_KEY", "")

SOLANA_AGENTS_URL = "http://solana_agents:4000"  # Container name + port
RAGCHAIN_URL      = "http://ragchain_service:5000"
EPHEMERAL_URL     = "http://ragchain_service:5000/ephemeral"  # Example route if you store ephemeral data

# Decide which LLM to use based on cost/complexity thresholds:
COMPLEXITY_THRESHOLD = 0.8
COST_THRESHOLD       = 0.8

###############################################################################
# HELPER: choose_llm_model()
# For demonstration, we'll prefer GPT-4 (OpenAI) if complexity is high, else fallback logic.
###############################################################################
def choose_llm_model(complexity_score=0.5, usage_cost_ratio=0.3):
    """
    Decide which LLM to use based on the 'complexity_score' and 'usage_cost_ratio'.
    0 <= complexity_score <= 1
    0 <= usage_cost_ratio <= 1 (approx ratio of monthly usage or cost so far)
    """
    if complexity_score > COMPLEXITY_THRESHOLD or usage_cost_ratio > COST_THRESHOLD:
        # If very complex or near cost limit, fallback to something cheaper or smaller
        # e.g., TAVILY or Google Gemini
        if TAVILY_KEY:
            return "TAVILY"
        elif GEMINI_KEY:
            return "GEMINI"
        else:
            # If no fallback, default to GPT-4 anyway, but warn
            print("[WARNING] No fallback LLM keys found. Using GPT-4 despite cost/complexity.")
            return "OPENAI_GPT4"
    else:
        # Normal usage => GPT-4 if openai key is available
        if OPENAI_KEY:
            return "OPENAI_GPT4"
        elif GEMINI_KEY:
            return "GEMINI"
        elif TAVILY_KEY:
            return "TAVILY"
        else:
            print("[ERROR] No LLM keys found. Can't proceed with summarization.")
            return None

###############################################################################
# HELPER: call_openai_gpt4()
###############################################################################
def call_openai_gpt4(prompt):
    """
    Calls OpenAI GPT-4. You must have openai library and OPENAI_API_KEY set.
    """
    if not OPENAI_KEY:
        print("[ERROR] No OPENAI_API_KEY found.")
        return None

    try:
        response = client.chat.completions.create(model="gpt-4",
        messages=[{"role": "system", "content": "You are a helpful quant summarizer."},
                  {"role": "user", "content": prompt}],
        max_tokens=1000,
        temperature=0.7)
        return response.choices[0].message.content
    except Exception as e:
        print(f"[ERROR] OpenAI GPT-4 call failed: {e}")
        return None

###############################################################################
# HELPER: call_gemini()
###############################################################################
def call_gemini(prompt):
    """
    Pseudocode for Google Gemini or other models. 
    Implement actual API calls with the GEMINI_KEY.
    """
    if not GEMINI_KEY:
        print("[ERROR] No GEMINI_API_KEY found.")
        return None

    # Example pseudo-API call:
    print("[INFO] (Pseudo) calling Google Gemini with prompt length:", len(prompt))
    # Return dummy result for demonstration:
    return "Gemini Summaries: " + prompt[:50] + "..."

###############################################################################
# HELPER: call_tavily()
###############################################################################
def call_tavily(prompt):
    """
    Pseudocode for TAVILY.
    """
    if not TAVILY_KEY:
        print("[ERROR] No TAVILY_API_KEY found.")
        return None

    print("[INFO] (Pseudo) calling TAVILY with prompt length:", len(prompt))
    return "TAVILY Summaries: " + prompt[:50] + "..."

###############################################################################
# GATHER: gather_data()
###############################################################################
def gather_data():
    """
    Gathers relevant stats from solana_agents, ephemeral memory, local quant stats, etc.
    Returns a dict with aggregated data.
    """
    output = {}

    # 1) GET solana_agents data (like balance, recent tx)
    try:
        resp = requests.get(f"{SOLANA_AGENTS_URL}/stats", timeout=10)
        if resp.status_code == 200:
            sa_data = resp.json()
            output["solana_agents"] = sa_data
        else:
            output["solana_agents_error"] = f"HTTP {resp.status_code}"
    except Exception as e:
        output["solana_agents_error"] = str(e)

    # 2) Possibly ephemeral chain-of-thought from ragchain_service or ephemeral DB
    try:
        # If ragchain_service has an ephemeral endpoint:
        ephemeral_resp = requests.get(f"{RAGCHAIN_URL}/ephemeral", timeout=10)
        if ephemeral_resp.status_code == 200:
            ephemeral_data = ephemeral_resp.json()
            output["chain_of_thought"] = ephemeral_data
        else:
            output["chain_of_thought_error"] = f"HTTP {ephemeral_resp.status_code}"
    except Exception as e:
        output["chain_of_thought_error"] = str(e)

    # 3) Local quant stats: If we store in a local DB or API, do similarly
    # For demonstration, let's pretend there's an endpoint or a local file:
    output["local_quant"] = {
        "PnL": 123.45,
        "recentTrades": 12,
        "winRate": 0.65
    }

    return output

###############################################################################
# CREATE PROMPT: create_prompt()
###############################################################################
def create_prompt(data):
    """
    Converts the gathered data into a prompt for the chosen LLM.
    """
    # Simplify as JSON or partial text:
    prompt = f"""
We have the following trading data and ephemeral logs:

(1) Solana Agents data: {data.get('solana_agents', 'N/A')}
(2) Chain-of-thought ephemeral data: {data.get('chain_of_thought', 'N/A')}
(3) Local quant stats: {data.get('local_quant', 'N/A')}

Please produce a concise, human-readable summary of key insights, 
notable trades, balance updates, and suggestions for next steps.
"""
    return prompt

###############################################################################
# MAIN: Summarize logic
###############################################################################
def main():
    print("[INFO] Gathering data for the full report...")
    data = gather_data()

    print("[INFO] Creating prompt from data...")
    prompt = create_prompt(data)

    # Example complexity/cost ratio calculations:
    # For demonstration, let's pick random or fixed values:
    complexity_score = 0.5
    usage_cost_ratio = 0.3

    print(f"[INFO] Deciding which LLM to call (complexity={complexity_score}, usage={usage_cost_ratio})...")
    model_choice = choose_llm_model(complexity_score, usage_cost_ratio)
    if not model_choice:
        print("[ERROR] No LLM model selected. Exiting.")
        sys.exit(1)

    print(f"[INFO] LLM choice is {model_choice}. Summarizing now...")

    summary = None
    if model_choice == "OPENAI_GPT4":
        summary = call_openai_gpt4(prompt)
    elif model_choice == "GEMINI":
        summary = call_gemini(prompt)
    elif model_choice == "TAVILY":
        summary = call_tavily(prompt)
    else:
        print("[ERROR] Unknown model choice or no keys available.")
        sys.exit(1)

    if summary is None:
        print("[ERROR] Summarization failed or returned None. Exiting.")
        sys.exit(1)

    print("\n=== FULL REPORT ===")
    print(summary)
    print("===================\n")

    # You might store the summary in ephemeral memory, a local file, or logs:
    # e.g., /tmp/daily_report.txt
    try:
        with open("/tmp/daily_report.txt", "w") as f:
            f.write(summary)
        print("[INFO] Summary saved to /tmp/daily_report.txt")
    except Exception as e:
        print(f"[WARNING] Could not save summary to file: {e}")

if __name__ == "__main__":
    main()
