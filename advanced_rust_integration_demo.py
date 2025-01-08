#!/usr/bin/env python3

import os
import sys
import logging
import asyncio
import json
import subprocess
import datetime
from typing import List, Dict, Any

# Google GenAI Imports
from google import genai
from google.genai import types

# Local Imports
from memory_manager import MemoryManager

###############################################################################
# LOGGING SETUP
###############################################################################
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

###############################################################################
# SIMPLE PERSISTED LEARNING DATA (NOT FULLY USED YET)
###############################################################################
LEARNING_DATA_FILE = "learning_data.json"

def load_learning_data() -> Dict[str, Any]:
    try:
        with open(LEARNING_DATA_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {"user_preferences": {}, "error_patterns": {}}
    except json.JSONDecodeError:
        logger.warning(f"Could not decode {LEARNING_DATA_FILE}, starting with empty data.")
        return {"user_preferences": {}, "error_patterns": {}}

def save_learning_data(data: Dict[str, Any]):
    with open(LEARNING_DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

###############################################################################
# LOCAL TOOL FUNCTIONS
###############################################################################
def generate_rust_file(filename: str, code: str) -> str:
    """
    Writes Rust code to the specified filename.
    Returns a short status message.
    """
    logger.info(f"(Local) generate_rust_file => {filename}")
    if not filename.endswith(".rs"):
        return f"[Error] Filename must end with .rs: {filename}"
    try:
        with open(filename, "w", encoding="utf-8") as f:
            f.write(code)
        return f"Successfully created {filename}."
    except Exception as e:
        return f"[Error] Could not write to {filename}: {str(e)}"

def cargo_check(project_path: str = ".") -> str:
    logger.info(f"(Local) cargo_check in {project_path}")
    try:
        result = subprocess.run(
            ["cargo", "check"], cwd=project_path,
            capture_output=True, text=True, check=True
        )
        return result.stdout + "\n" + result.stderr
    except subprocess.CalledProcessError as e:
        return f"[Error] cargo check failed:\n{e.stderr}"
    except FileNotFoundError:
        return "[Error] cargo command not found. Is Rust installed?"

def cargo_fmt(project_path: str = ".") -> str:
    logger.info(f"(Local) cargo_fmt in {project_path}")
    try:
        result = subprocess.run(
            ["cargo", "fmt"], cwd=project_path,
            capture_output=True, text=True, check=True
        )
        return "Code formatted successfully.\n" + result.stdout + "\n" + result.stderr
    except subprocess.CalledProcessError as e:
        return f"[Error] cargo fmt failed:\n{e.stderr}"
    except FileNotFoundError:
        return "[Error] cargo command not found. Is Rust installed?"

###############################################################################
# MAIN DEMO CLASS
###############################################################################
class AdvancedRustDemo:
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY not set in environment. Please export it.")
        self.client = genai.Client(api_key=self.api_key)
        self.learning_data = load_learning_data()

        self.tools_config = [
            types.Tool(function_declarations=[{
                "name": "generate_rust_file",
                "description": "Generate a Rust code file locally.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "filename": {"type": "STRING", "description": "The name of the .rs file"},
                        "code": {"type": "STRING", "description": "The Rust code content"}
                    },
                    "required": ["filename", "code"]
                }
            }]),
            types.Tool(function_declarations=[{
                "name": "cargo_check",
                "description": "Run 'cargo check' to verify if the Rust code compiles.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "project_path": {"type": "STRING", "description": "Path to the Rust project (optional)."}
                    }
                }
            }]),
            types.Tool(function_declarations=[{
                "name": "cargo_fmt",
                "description": "Run 'cargo fmt' to format the Rust code.",
                "parameters": {
                    "type": "OBJECT",
                    "properties": {
                        "project_path": {"type": "STRING", "description": "Path to the Rust project (optional)."}
                    }
                }
            }])
        ]
        self.memory = MemoryManager()

    def _describe_tools(self) -> str:
        """
        Returns a user-friendly listing of the local tools we provide.
        Accesses the name / description of each FunctionDeclaration
        via dot-notation, rather than subscript.
        """
        lines = []
        for tool in self.tools_config:
            for decl in tool.function_declarations:
                # decl is a FunctionDeclaration object, not a dict.
                name = getattr(decl, "name", None)
                description = getattr(decl, "description", None)
                if name and description:
                    lines.append(f"* {name}: {description}")
                else:
                    # fallback: if the library didn't store them
                    lines.append("* <FunctionDeclaration missing name/description>")
        return "\n".join(lines)

    async def run_demo(self):
        user_prompts = [
            "Create a simple Rust function to add two numbers.",
            "Now, ensure that this code compiles.",
            "Format the code nicely.",
            "Could you create a more complex example with concurrency, and then check if it compiles?",
            "Let's build a basic REST API endpoint using actix-web. Propose a plan first.",
        ]

        for user_text in user_prompts:
            logger.info(f"\n=== User Prompt: {user_text} ===")
            await self._handle_user_prompt(user_text)

        logger.info("\n=== Demo complete ===")
        save_learning_data(self.learning_data)

    async def _handle_user_prompt(self, user_text: str):
        intent_understanding = await self._understand_intent(user_text)
        logger.info(f"[Intent Understanding] {intent_understanding}")
        self._log_training(f"[Intent Understanding] {user_text} : {intent_understanding}")
        prompt = f"""You are an expert Rust coding system. User request: {user_text}\n\n{intent_understanding}\n\
You can use the following tools:\n{self._describe_tools()}\nThink step-by-step."""

        response = self.client.models.generate_content(
            model="gemini-2.0-flash-exp",
            contents=prompt,
            config=types.GenerateContentConfig(tools=self.tools_config, temperature=0.1),
        )
        self._log_training(f"[LLM call after user prompt]")
        await self._process_response(user_text, response)


    async def _understand_intent(self, user_text: str) -> str:
        return f"Acknowledging user request: '{user_text}'. I will try my best to fulfill it."

    async def _process_response(self, user_text: str, response: types.GenerateContentResponse):
        if not response.candidates:
            logger.warning("No response candidates from the model.")
            return

        for candidate in response.candidates:
            if not candidate.content or not candidate.content.parts:
                continue

            for part in candidate.content.parts:
                if part.text:
                    logger.info(f"[LLM Response]: {part.text}")
                    self.memory.add_conversation_turn(user_text, part.text)
                elif part.function_call:
                    await self._handle_function_call(user_text, part.function_call)

    async def _handle_function_call(self, user_text: str, function_call: types.FunctionCall):
        fn_name = function_call.name
        args = function_call.args or {}
        logger.info(f"[Function Call Requested]: {fn_name} with args: {args}")

        function_results = ""
        if fn_name == "generate_rust_file":
            filename = args.get("filename")
            code = args.get("code")
            if filename and code:
                function_results = generate_rust_file(filename, code)
                await self._make_proactive_suggestions(user_text, filename)
            else:
                function_results = "[Error] Missing 'filename' or 'code' in arguments."
        elif fn_name == "cargo_check":
            project_path = args.get("project_path", ".")
            function_results = cargo_check(project_path)
            if "[Error]" in function_results:
                await self._attempt_self_correction(user_text, function_results)
        elif fn_name == "cargo_fmt":
            project_path = args.get("project_path", ".")
            function_results = cargo_fmt(project_path)
        else:
            function_results = f"[Error] Unknown function: {fn_name}"

        logger.info(f"[Function Call Result]: {function_results}")
        self._log_interaction(user_text, fn_name, args, function_results)
        self.memory.add_conversation_turn(f"Function call: {fn_name} with {args}", function_results)

    async def _make_proactive_suggestions(self, user_text: str, filename: str):
        if filename.endswith(".rs"):
            prompt = f"User generated file '{filename}'. Should I suggest a cargo check? Respond 'yes' or 'no'."
            response = self.client.models.generate_content(model="gemini-2.0-flash-exp", contents=prompt, temperature=0.1)
            if response.candidates and response.candidates[0].content and response.candidates[0].content.parts and \
               "yes" in response.candidates[0].content.parts[0].text.lower():
                logger.info("[Proactive Suggestion] Suggesting cargo check.")
                check_result = cargo_check()
                logger.info(f"[Proactive Suggestion Result]: {check_result}")

    async def _attempt_self_correction(self, user_text: str, error_message: str):
        logger.info("[Self-Correction Attempt] Received error, attempting to fix...")
        self._log_training(f"[Self-Correction Attempt] Received error: {error_message} for {user_text}")
        prompt = f"The Rust code generated resulted in the following error:\n\n{error_message}\n\nUser's original request: {user_text}\n\nPlease provide the corrected code."
        response = self.client.models.generate_content(model="gemini-2.0-flash-exp", contents=prompt, temperature=0.2)
        if response.candidates and response.candidates[0].content and response.candidates[0].content.parts:
            corrected_code = response.candidates[0].content.parts[0].text
            self._log_training(f"[Self-Correction Attempt]  Corrected code recieved")
            logger.info(f"[Self-Correction Attempt] Corrected Code:\n{corrected_code}")

    def _log_interaction(self, user_text: str, function_name: str, args: Dict[str, Any], result: str):
        timestamp = datetime.datetime.now().isoformat()
        log_entry = {
            "timestamp": timestamp,
            "user_text": user_text,
            "function_called": function_name,
            "arguments": args,
            "result": result,
        }
        with open("interaction_log.jsonl", "a") as f:
            f.write(json.dumps(log_entry) + "\n")

    async def _propose_plan(self, user_text: str):
        prompt = f"User wants to: '{user_text}'. Propose a step-by-step plan to achieve this."
        response = self.client.models.generate_content(model="gemini-2.0-flash-exp", contents=prompt, temperature=0.4)
        if response.candidates and response.candidates[0].content and response.candidates[0].content.parts:
            plan = response.candidates[0].content.parts[0].text
            logger.info(f"[Proposed Plan]:\n{plan}")

    def _log_training(self, event: str):
        """Logs to training_log.txt."""
        timestamp = datetime.datetime.now().isoformat()
        log_entry = f"{timestamp}: {event}\n"
        with open("training_log.txt", "a") as f:
            f.write(log_entry)

async def main():
    demo = AdvancedRustDemo()
    await demo.run_demo()

if __name__ == "__main__":
    import datetime
    asyncio.run(main())
