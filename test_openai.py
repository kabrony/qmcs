import os
import openai

openai.api_key = os.getenv("OPENAI_API_KEY")

try:
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": "Hello from the new library!"}]
    )
    print(resp.choices[0].message.content)
except Exception as e:
    print(f"Error: {e}")
