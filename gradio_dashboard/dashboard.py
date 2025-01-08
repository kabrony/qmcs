import os
import gradio as gr
from google import genai
from google.genai import types

API_KEY = os.getenv("GEMINI_API_KEY", "")

client = genai.Client(api_key=API_KEY)

def gemini_inference(user_prompt):
    if not API_KEY:
        return "ERROR: No GEMINI_API_KEY found."
    try:
        response = client.models.generate_content(
            model="gemini-2.0-flash-exp",
            contents=user_prompt,
            config=types.GenerateContentConfig(
                temperature=0.7,
                candidate_count=1
            )
        )
        return response.text
    except Exception as e:
        return f"Error: {e}"

def chatbot_interface(user_input, history):
    bot_reply = gemini_inference(user_input)
    history.append((user_input, bot_reply))
    return history, history

with gr.Blocks(theme=gr.themes.Monochrome()) as demo:
    gr.Markdown("## Dark-Themed Gemini Pro Dashboard")
    chatbot = gr.Chatbot(label="Gemini Pro Chat")
    user_box = gr.Textbox(label="Type your message here")

    user_box.submit(
        fn=chatbot_interface,
        inputs=[user_box, chatbot],
        outputs=[chatbot, chatbot],
        scroll_to_output=True
    )

demo.launch(server_name="0.0.0.0", server_port=7880, share=True)
