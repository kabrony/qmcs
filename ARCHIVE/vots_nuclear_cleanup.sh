#!/usr/bin/env bash
set -e

###############################################################################
# 1) Comment out any apt-get lines
###############################################################################
echo "[INFO] Commenting out apt-get calls in final_extreme_monitor_v4.sh..."
sed -i 's/^[ \t]*apt-get /#apt-get /g' final_extreme_monitor_v4.sh
sed -i 's/^[ \t]*apt-get/#apt-get /g' final_extreme_monitor_v4.sh

###############################################################################
# 2) Remove everything from 'Requesting AI summary' to the end of file
###############################################################################
echo "[INFO] Removing everything from 'Requesting AI summary' to EOF..."
sed -i '/Requesting AI summary/,$d' final_extreme_monitor_v4.sh

###############################################################################
# 3) Append a SINGLE, fresh ChatCompletion snippet
###############################################################################
echo "[INFO] Appending brand-new ChatCompletion snippet..."

cat << 'CHATCODE' >> final_extreme_monitor_v4.sh

##############################################################################
# FINAL CLEAN AI SUMMARY SNIPPET
# for openai>=1.0.0 using ChatCompletion
##############################################################################

echo "[NOTE] Requesting AI summary from OpenAI (via ChatCompletion)..."

python3 <<PYCODE
import os
import openai

api_key = os.environ.get("OPENAI_API_KEY", "")
logs_content = os.environ.get("ALL_LOGS", "")

if not api_key:
    print("[ERROR] No OPENAI_API_KEY found; skipping AI summary.")
else:
    try:
        openai.api_key = api_key
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
        answer = resp.choices[0].message["content"]
        print("--- AI Summary ---")
        print(answer.strip())
        print("--- End of AI Summary ---")
    except Exception as exc:
        print(f"[ERROR] openai.ChatCompletion failed: {exc}")
PYCODE

echo "[NOTE] final_extreme_monitor_v4.sh complete! (No leftover partial lines, single snippet.)"
CHATCODE

echo "[INFO] Done patching final_extreme_monitor_v4.sh with a single fresh snippet!"
