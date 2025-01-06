import openai

print("OpenAI version:", openai.__version__)

try:
    resp = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": "Hello from the new library!"}],
    )
    print("Response content:", resp.choices[0].message.content)
except Exception as e:
    print("Error testing ChatCompletion:", e)
