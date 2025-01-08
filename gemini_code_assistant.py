#!/usr/bin/env python3
import os
import google.generativeai as genai
from google.generativeai.types import FunctionDeclaration
from typing import Dict, Any
from gemini_tools import (
    generate_new_file, list_files_in_repo, review_code,
    handle_function_call
)

def call_gemini(prompt: str) -> dict:
    """
    Sends a prompt to the Gemini model with a set of local functions.
    Returns the function_call data if a function is called,
    or returns text if the response is textual.
    """
    # 1) Configure API key and instantiate the model
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel("gemini-pro")

    # 2) Build function declarations from local functions
    func_decls = [
        FunctionDeclaration.from_function(generate_new_file),
        FunctionDeclaration.from_function(list_files_in_repo),
        FunctionDeclaration.from_function(review_code)
    ]

    # 3) Define the tools configuration
    tools_config = {
        "function_declarations": func_decls,
        "function_calling_config": {"mode": "ANY"}
    }

    # 4) Generate content, passing tools_config directly
    response = model.generate_content(
        prompt=prompt,
        tools=tools_config
    )

    # 5) Parse the response
    if not response.parts:
        return {"error": "No parts in Gemini response."}

    part = response.parts[0]
    if part.function_call:
        return {
            "function_call": {
                "name": part.function_call.name,
                "arguments": part.function_call.args
            }
        }
    else:
        return {"text": part.text}

def main():
    """
    Minimal demonstration of orchestrating a model call
    and handling function calls in a loop.
    """
    test_prompt = (
        "Hello, Gemini. I want you to generate_new_file "
        "with filename='demo_script.py', description='simple example', "
        "function_signature='def main():\\n    pass'."
    )

    print("[INFO] Sending prompt to Gemini...")
    result = call_gemini(test_prompt)

    if "function_call" in result:
        fc = result["function_call"]
        # Dispatch the call to local Python functions
        local_result = handle_function_call(fc)
        print(f"[INFO] Local function call result:\n{local_result}")
    else:
        print("[INFO] Gemini returned text instead of a function call:")
        print(result.get("text"))

if __name__ == "__main__":
    main()
