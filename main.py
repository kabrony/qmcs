import os
import openai
from dotenv import load_dotenv

def main():
    load_dotenv()
    openai.api_key = os.getenv("OPENAI_API_KEY", "DUMMY_KEY")
    # New usage for openai >= 1.0.0
    response = openai.chat_complete(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": "Hello from new openai library!"}]
    )
    print(response["choices"][0]["message"]["content"])

if __name__ == "__main__":
    main()
