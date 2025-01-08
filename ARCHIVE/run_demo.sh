#!/bin/bash

# Activate the virtual environment
source .venv/bin/activate

# Set your Gemini API key (replace with your actual key)
export GEMINI_API_KEY="AIzaSyB72tnxwOYzM4ZXsHRj5KbXmHZ_AWTAFF4"

# Run the Python script
python advanced_rust_integration_demo.py

# Deactivate the virtual environment (optional, but good practice)
deactivate
