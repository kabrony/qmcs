#!/usr/bin/env bash
set -e

# 1) Activate your Python env named "myenv" (adjust path if needed):
source /home/oxdev/qmcs/myenv/bin/activate

# 2) Upgrade pip and install google-genai
pip install --upgrade pip
pip install google-genai Pillow tenacity requests

# 3) Quick check
pip show google-genai
