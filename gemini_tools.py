#!/usr/bin/env python3
import os
import google.generativeai as genai
from google.generativeai.types import FunctionDeclaration
from typing import Dict, Any

###############################################################################
# gemini_tools.py
###############################################################################

def generate_new_file(filename: str, description: str, function_signature: str) -> str:
    """
    Generates a new Python file with a specified function signature
    and short description, then returns the content of that file as a string.

    Example usage:
      generate_new_file("cool_script.py", "A script for demonstration", "def cool_func(): pass")
    """
    prompt = (
        f"Generate a Python file named '{filename}'.\n"
        f"Description: {description}\n"
        f"Function signature: {function_signature}\n"
        "Ensure it's well-commented and follows best practices.\n"
    )
    # 1) Configure and call the model for code generation
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel("gemini-pro")

    # 2) Generate the content
    response = model.generate_content(prompt)

    # 3) Return text as the "file content"
    return response.text or ""

def list_files_in_repo(path: str, depth: int) -> str:
    """
    Lists file paths in a repository (placeholder).

    Args:
      path (str): directory path to list
      depth (int): recursion depth
    Returns:
      str: A placeholder string enumerating file paths
    """
    # This could be replaced by actual logic that walks the file tree.
    return f"Files in {path} up to depth {depth} (placeholder)."

def review_code(content: str) -> str:
    """
    Reviews a code snippet and returns suggestions or revised code.

    Args:
      content (str): The code snippet to review
    Returns:
      str: An improved or annotated version of the code
    """
    return f"Reviewed code for:\n{content}\n[No actual logic here—placeholder]."

###############################################################################
# DISPATCHER (map Gemini calls to local Python functions)
###############################################################################

# Mapping of function_name -> local_function
LOCAL_FUNCTIONS = {
    "generate_new_file": generate_new_file,
    "list_files_in_repo": list_files_in_repo,
    "review_code": review_code
}

def handle_function_call(fc_dict: Dict[str, Any]) -> str:
    """
    Dispatches a Gemini function call to a corresponding local Python function.

    Args:
        fc_dict (dict): A dictionary with structure:
            {
              "name": "<function_name>",
              "arguments": {...}  # key-value pairs for function params
            }

    Returns:
        A string representing either:
         - The result of the called local function, OR
         - An error message if the function isn't recognized or arguments are invalid.

    Example:
        fc_dict = {
          "name": "generate_new_file",
          "arguments": {
            "filename": "example.py",
            "description": "A short script",
            "function_signature": "def test(): pass"
          }
        }
    """
    fname = fc_dict.get("name")
    args  = fc_dict.get("arguments", {})

    # Basic check: function name must be recognized
    if not fname or fname not in LOCAL_FUNCTIONS:
        return f"[ERROR] Unknown or missing function name: {fname}"

    # Minimal argument validation example
    if fname == "generate_new_file":
        if not args.get("filename", "").endswith(".py"):
            return "[ERROR] 'filename' must end with '.py' for safety."

    # Attempt to call local function
    func = LOCAL_FUNCTIONS[fname]
    try:
        result = func(**args)
        return result if isinstance(result, str) else str(result)
    except TypeError as te:
        return f"[ERROR] Mismatch in function arguments: {te}"
