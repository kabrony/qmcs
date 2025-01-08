#!/bin/bash
set -e

# --- Activate the virtual environment ---
source /home/oxdev/qmcs/myenv/bin/activate

# --- Ensure necessary packages are installed ---
echo "Ensuring required Python packages are installed..."
pip install --upgrade pip
pip install google-genai Pillow tenacity requests

# --- Make the Python script executable ---
echo "Making the Python script executable..."
chmod +x advanced_solana_zk_demo.py

# --- Run the Python script ---
echo "Running the Python script..."
./advanced_solana_zk_demo.py
