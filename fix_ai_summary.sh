#!/usr/bin/env bash
set -e

echo "[INFO] Removing old AI summary snippet in final_extreme_monitor_v4.sh..."

# 1) Remove lines from the line containing 'Requesting AI summary from OpenAI'
#    up to the next blank line. Adjust if needed.
sed -i '/Requesting AI summary from OpenAI/,/^$/d' final_extreme_monitor_v4.sh

echo "[INFO] Appending new Python heredoc snippet with ChatCompletion..."

# 2) Append a safe Python heredoc snippet at the bottom.
cat << 'CHATCODE' >> final_extreme_monitor_v4.sh

echo "[NOTE] Requesting AI summary from OpenAI using ChatCompletion..."

python <<PYEOF
import os
import openai

# Use environment variable for API key
openai.api_key = os.getenv("OPENAI_API_KEY", "")

# logs_content is presumably the string variable in shell containing your logs
# e.g. logs_content = """${ALL_LOGS}"""
# We'll assume it was exported to the environment or inlined. 
# For example, if your script sets: ALL_LOGS="whatever" before calling this block,
# we inject it below. If your variable is named differently, rename accordingly.

logs_content = """${ALL_LOGS}"""

try:
        model="gpt-3.5-turbo",
        messages=[
            {
                "role": "system",
                "content": (
                    "You are a helpful assistant analyzing logs from a Solana-based "
                    "quant trading system called VOTS. Summarize key trades, errors, or "
                    "anomalies, and provide recommended next steps."
                ),
            },
            {
                "role": "user",
                "content": logs_content
            },
        ],
        max_tokens=500,
        temperature=0.2,
    )
    summary_text = response.choices[0].message["content"]
    print("--- AI Summary ---")
    print(summary_text.strip())
    print("--- End of AI Summary ---")

except Exception as e:
    print(f"[WARN] Could not produce AI summary: {e}")
PYEOF

CHATCODE

echo "[INFO] Done. AI snippet replaced with a python heredoc approach."
