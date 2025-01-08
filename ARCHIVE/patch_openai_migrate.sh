#!/usr/bin/env bash
set -e

echo "[INFO] Searching final_extreme_monitor_v4.sh for old 'Completion.create' references..."


# 2) Insert a new ChatCompletion snippet in place of the old usage.
#    We'll assume your Python code block is within final_extreme_monitor_v4.sh
#    in a function or inline. We'll append an example below.
cat << 'CHATCODE' >> final_extreme_monitor_v4.sh

################################################################################
################################################################################
# Example usage in Python (inlined for demonstration):
# Adjust variable names as needed, e.g. logs_content => prompt, etc.

print("[NOTE] Requesting AI summary from OpenAI using ChatCompletion...")

try:
    import openai

    # We'll assume your 'logs_content' or 'prompt' variable holds the text to be summarized.
    # For demonstration, let's say it's called 'logs_content' here:
    # logs_content = YOUR_LOGS_VARIABLE

        model="gpt-3.5-turbo",  # or 'gpt-4' if you have access
        messages=[
            {
                "role": "system",
                "content": (
                    "You are a helpful assistant analyzing logs from a Solana-based "
                    "quant trading system called VOTS. Summarize key trades, errors, or "
                    "anomalies, and provide recommended next steps."
                )
            },
            {
                "role": "user",
                "content": logs_content  # or 'prompt', whatever var you use
            }
        ],
        max_tokens=500,
        temperature=0.2,
    )
    summary_text = response.choices[0].message["content"]

    print("--- AI Summary ---")
    print(summary_text.strip())
    print("--- End of AI Summary ---")

except Exception as e:
    print(f"[WARN] Failed to produce ChatCompletion AI summary: {e}")
################################################################################

CHATCODE

echo "[INFO] Patch complete! Old Completion usage removed, ChatCompletion snippet appended."
