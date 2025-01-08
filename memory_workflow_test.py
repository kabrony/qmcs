#!/usr/bin/env python3

import asyncio
import httpx
import os
import sys

"""
Simple memory workflow test script that:
1) Adds a test document to the openai_service (which presumably calls ragchain and mongo behind the scenes).
2) Asks a question referencing that memory, using a "query" key in JSON (as your 422 error suggests).
3) Validates the response.

Usage:
  1) Ensure environment variables (if needed):
     export OPENAI_SERVICE_URL="http://localhost:5103"
     export RAGCHAIN_SERVICE_URL="http://localhost:5105"
  2) Make executable (chmod +x memory_workflow_test.py) and run it:
     ./memory_workflow_test.py
"""

API_TIMEOUT = 20.0  # seconds for each request


async def test_add_doc_and_ask():
    # Read the openai_service address from env or fallback
    openai_service_url = os.getenv("OPENAI_SERVICE_URL", "http://localhost:5103")
    memory_service_url = os.getenv("RAGCHAIN_SERVICE_URL", "http://localhost:5105")

    # 1) Add a doc (simulate memory insertion)
    add_doc_endpoint = f"{openai_service_url}/add_doc"
    doc_payload = {
        "text": "Solana is a high-performance blockchain with low fees."
    }

    print(f"[1] Adding doc to: {add_doc_endpoint}")
    async with httpx.AsyncClient(timeout=API_TIMEOUT) as client:
        try:
            add_resp = await client.post(add_doc_endpoint, json=doc_payload)
            add_resp.raise_for_status()
            add_data = add_resp.json()
            print("Add doc response:", add_data)
        except Exception as e:
            print(f"FAILED: Could not add doc to openai_service.\nError: {e}")
            return False

    # 2) Ask referencing that memory. The service expects "query" and "max_tokens".
    ask_endpoint = f"{openai_service_url}/ask"
    ask_payload = {
        "query": "What is Solana known for?",
        "max_tokens": 50
    }

    print(f"[2] Asking question to: {ask_endpoint}")
    async with httpx.AsyncClient(timeout=API_TIMEOUT) as client:
        try:
            ask_resp = await client.post(ask_endpoint, json=ask_payload)
            ask_resp.raise_for_status()  # raises HTTPStatusError if 4xx/5xx
            answer_data = ask_resp.json()
            print("Ask response:", answer_data)

            # Check if the answer references relevant text
            answer_text = answer_data.get("answer", "").lower()
            if "low fees" in answer_text or "high performance" in answer_text or "solana" in answer_text:
                print("[SUCCESS] The memory workflow looks correct!")
                return True
            else:
                print("[WARNING] The answer may not contain the expected text. Check logs/response manually.")
                return False

        except httpx.HTTPStatusError as http_err:
            print(f"FAILED: Could not ask question (status {http_err.response.status_code}).")
            print(f"Response text: {http_err.response.text}")
            return False
        except Exception as e:
            print(f"FAILED: Could not ask question to openai_service.\nError: {e}")
            return False


async def main():
    print("Running memory workflow test...")
    success = await test_add_doc_and_ask()

    if success:
        print("=== Memory Workflow Test Completed Successfully ===")
        sys.exit(0)
    else:
        print("=== Memory Workflow Test FAILED ===")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
