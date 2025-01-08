#!/usr/bin/env bash
cd gradio_dashboard
export GEMINI_API_KEY="AIzaSyB72tnxwOYzM4ZXsHRj5KbXmHZ_AWTAFF4"
pip install --no-cache-dir -r requirements.txt
python dashboard.py
