#!/usr/bin/env python3
"""
test_openai_new_api.py

Demonstrates how to call OpenAI's new Chat API in openai>=1.0.0.
This replaces the old 'openai.ChatCompletion.create(...)' usage.
"""

import os
import openai

# 1) Ensure your environment variable is set, or do it here in code:
# os.environ["OPENAI_API_KEY"] = "YOUR_API_KEY"
openai.api_key = os.getenv("OPENAI_API_KEY", "YOUR_API_KEY")

def main():
    try:
        # 2) Prepare a list of role-based messages (system, user, assistant, etc.)
        messages = [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "Hello from the new usage example!"}
        ]

        # 3) Use the new openai.chat.completions.create(...) call
        response = openai.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=messages
        )

        # 4) Print the response
        #    If successful, you'll see the assistant's reply.
        print("Model reply:", response.choices[0].message.content)

    except Exception as e:
        print("Error using 'openai.chat.completions.create':", e)

if __name__ == "__main__":
    main()
