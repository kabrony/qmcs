#!/usr/bin/env bash
set -e

###############################################################################
# 1) Comment out apt-get calls
###############################################################################
echo "[INFO] Commenting out apt-get calls in final_extreme_monitor_v4.sh..."
sed -i 's/^[ \t]*apt-get /#apt-get /g' final_extreme_monitor_v4.sh
sed -i 's/^[ \t]*apt-get/#apt-get /g' final_extreme_monitor_v4.sh

###############################################################################
# 2) Remove code from 'Requesting AI summary' to EOF
###############################################################################
echo "[INFO] Removing old AI snippet from 'Requesting AI summary' to end-of-file..."
sed -i '/Requesting AI summary/,$d' final_extreme_monitor_v4.sh

###############################################################################
# 3) Append brand-new ChatCompletion snippet
###############################################################################
echo "[INFO] Appending new ChatCompletion snippet at the end..."

cat << 'CHATCODE' >> final_extreme_monitor_v4.sh

##############################################################################
# CLEAN AI SUMMARY SNIPPET for openai>=1.0.0
##############################################################################
echo "[NOTE] Requesting AI summary from OpenAI (via ChatCompletion)..."

# Usage example:
#   export OPENAI_API_KEY="sk-..."
#   export ALL_LOGS="some logs"
# Then run: ./final_extreme_monitor_v4.sh

python3 <<PYCODE
import os
import openai

openai.api_key = os.getenv("OPENAI_API_KEY", "")
logs_content = os.getenv("ALL_LOGS", "")

if not openai.api_key:
    print("[ERROR] No OPENAI_API_KEY found in environment.")
else:
    try:
            model="gpt-3.5-turbo",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a helpful assistant analyzing logs from a Solana-based "
                        "quant trading system called VOTS. Summarize key trades, errors, "
                        "or anomalies, and provide recommended next steps."
                    )
                },
                {
                    "role": "user",
                    "content": logs_content
                }
            ],
            max_tokens=500,
            temperature=0.2
        )
        ai_text = resp.choices[0].message["content"]
        print("--- AI Summary ---")
        print(ai_text.strip())
        print("--- End of AI Summary ---")
    except Exception as e:
        print(f"[ERROR] openai.ChatCompletion failed: {e}")
PYCODE

echo "[NOTE] final_extreme_monitor_v4.sh complete (no leftover partial lines)."
CHATCODE

echo "[INFO] Done patching final_extreme_monitor_v4.sh!"
