#!/bin/bash
set -e

# --- Ensure we are in the correct directory (optional, adjust if needed) ---
cd /home/oxdev/qmcs || { echo "Error: Could not navigate to /home/oxdev/qmcs"; exit 1; }

# --- Check if the virtual environment exists, create if not ---
if [ ! -d "myenv" ]; then
    echo "Creating virtual environment 'myenv'..."
    python3 -m venv myenv
    if [ $? -ne 0 ]; then
        echo "Error creating virtual environment. Make sure python3 and venv are installed."
        exit 1
    fi
else
    echo "Virtual environment 'myenv' already exists."
fi

# --- Activate the virtual environment ---
echo "Activating virtual environment 'myenv'..."
source myenv/bin/activate

# --- Install necessary Python packages ---
echo "Installing required Python packages..."
pip install --upgrade pip
pip install google-genai Pillow tenacity requests

# --- Create the Python script ---
echo "Creating the Python script 'advanced_solana_zk_demo.py'..."
cat << 'PY_EOF' > advanced_solana_zk_demo.py
#!/home/oxdev/qmcs/myenv/bin/python

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

DARK_BG = "\x1b[48;2;30;30;30m"
HIGH_CONTRAST_FG = "\x1b[38;2;255;255;255m"
RESET_ANSI = "\x1b[0m"

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

class MemoryManager:
    def __init__(self, filename: str = "advanced_memory.json"):
        self.filename = filename
        self.memory_data = {"conversations": [], "insights": []}
        self._load()

    def _load(self):
        if os.path.exists(self.filename):
            try:
                with open(self.filename, "r", encoding="utf-8") as f:
                    self.memory_data = json.load(f)
            except json.JSONDecodeError:
                dark_print("Could not decode memory file—starting fresh.", "WARN")
        else:
            dark_print("No prior memory file found—starting fresh.", "INFO")

    def _save(self):
        with open(self.filename, "w", encoding="utf-8") as f:
            json.dump(self.memory_data, f, indent=2)

    def add_conversation_turn(self, user_input: str, assistant_output: str):
        turn_info = {
            "timestamp": datetime.datetime.now().isoformat(),
            "user_input": user_input,
            "assistant_output": assistant_output
        }
        self.memory_data["conversations"].append(turn_info)
        self._save()

        # Placeholder for Gemini interaction (replace with actual logic)
        dark_print(f"User: {user_input}", "INFO")
        dark_print(f"Assistant: {assistant_output}", "INFO")

def main():
    memory_manager = MemoryManager()
    dark_print("Starting advanced Solana ZK demo...", "INFO")

    while True:
        try:
            user_input = input(f"{HIGH_CONTRAST_FG}(User) >>> {RESET_ANSI}")
            if user_input.lower() in ["exit", "quit"]:
                dark_print("Exiting...", "INFO")
                break

            # Simulate assistant response
            assistant_response = f"Simulated response to: {user_input}"

            memory_manager.add_conversation_turn(user_input, assistant_response)

        except KeyboardInterrupt:
            dark_print("\nExiting due to keyboard interrupt...", "WARN")
            break
        except Exception as e:
            dark_print(f"Unexpected error: {e}", "ERROR")

if __name__ == "__main__":
    main()
PY_EOF

# --- Make the Python script executable ---
echo "Making the Python script executable..."
chmod +x advanced_solana_zk_demo.py

# --- Run the Python script ---
echo "Running the Python script..."
./advanced_solana_zk_demo.py

