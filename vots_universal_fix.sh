#!/usr/bin/env bash
set -e

###############################################################################
# 1) Comment out all apt-get calls
###############################################################################
echo "[INFO] Commenting out apt-get calls in final_extreme_monitor_v4.sh..."
sed -i 's/^[ \t]*apt-get /#apt-get /g' final_extreme_monitor_v4.sh
sed -i 's/^[ \t]*apt-get/#apt-get /g' final_extreme_monitor_v4.sh

###############################################################################
# 2) Remove lines from 'Requesting AI summary' to EOF
###############################################################################
echo "[INFO] Removing code from 'Requesting AI summary' to end-of-file..."
sed -i '/Requesting AI summary/,$d' final_extreme_monitor_v4.sh

###############################################################################
# 3) Append a brand-new Python ChatCompletion snippet
###############################################################################
echo "[INFO] Appending new ChatCompletion snippet at the end of final_extreme_monitor_v4.sh..."

cat << 'CHAT' >> final_extreme_monitor_v4.sh

##############################################################################
# CLEAN AI SUMMARY SNIPPET (no leftover partial lines)
##############################################################################
echo "[NOTE] Requesting AI summary from OpenAI (via ChatCompletion)..."

# Example usage (before running final_extreme_monitor_v4.sh):
# export OPENAI_API_KEY="sk-..."
# export ALL_LOGS="some logs content"

python3 <<PYEOF
import os
import openai

openai.api_key = os.getenv("OPENAI_API_KEY", "")
logs_content = os.getenv("ALL_LOGS", "")

if not openai.api_key:
    print("[ERROR] No OPENAI_API_KEY set. Cannot do AI summary.")
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
            temperature=0.2,
        )
        ai_summary = response.choices[0].message["content"]
        print("--- AI Summary ---")
        print(ai_summary.strip())
        print("--- End of AI Summary ---")
    except Exception as e:
        print(f"[ERROR] openai.ChatCompletion failed: {e}")
PYEOF

echo "[NOTE] final_extreme_monitor_v4.sh complete! (No leftover partial code.)"
CHAT

echo "[INFO] Done patching final_extreme_monitor_v4.sh. Now run it with './final_extreme_monitor_v4.sh'!"
