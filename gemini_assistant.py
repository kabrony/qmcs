
#!/usr/bin/env python3

import os
import time
import logging
import asyncio
import signal
import json
from typing import Dict, Any, Optional, List

# Google Generative AI imports (v0.8+)
import google.generativeai as genai
from google.generativeai.types import (
    FunctionDeclaration,
    GenerateContentResponse
)

###############################################################################
# LOGGING SETUP
###############################################################################
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('gemini_debug.log')
    ]
)
logger = logging.getLogger(__name__)

###############################################################################
# GEMINI CLIENT
###############################################################################
class GeminiClient:
    """
    GeminiClient sets up a google.generativeai "gemini-pro" model
    and handles tool-based function calls using generate_content(...).
    """
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY not set in environment.")

        # Start time for measuring durations
        self.start_time = time.time()

        # Configure generative AI with the user’s API key
        genai.configure(api_key=self.api_key)

        # The model name "gemini-pro" may differ if you have a different endpoint
        self.model = genai.GenerativeModel("gemini-pro")

        # Tools (function declarations) that the LLM can call
        self.tools_config = [
            FunctionDeclaration(
                name="generate_file",
                description="Generate a Python file",
                parameters={
                    "type": "object",
                    "properties": {
                        "filename": {
                            "type": "string",
                            "description": "Name of the file to generate"
                        },
                        "content": {
                            "type": "string",
                            "description": "Content of the file"
                        }
                    },
                    "required": ["filename", "content"]
                }
            ),
            FunctionDeclaration(
                name="review_code",
                description="Review Python code and suggest improvements",
                parameters={
                    "type": "object",
                    "properties": {
                        "code": {
                            "type": "string",
                            "description": "Code snippet to review"
                        }
                    },
                    "required": ["code"]
                }
            )
        ]

    async def call_gemini(self,
                          prompt: str,
                          max_retries: int = 3,
                          retry_delay: float = 2.0
                          ) -> Optional[str]:
        """
        Send a text prompt to Gemini using generate_content(..., tool_config=...),
        then parse text or function calls if present.

        :param prompt: The user’s request or instructions for Gemini.
        :param max_retries: Number of attempts before giving up on errors.
        :param retry_delay: Initial delay (in seconds) between retries.
        :return: Combined text from the model, or None if we bail out early.
        """
        attempt = 0
        last_error = None

        while attempt < max_retries:
            attempt += 1
            try:
                # Use the updated generate_content call
                response: GenerateContentResponse = self.model.generate_content(
                    prompt=prompt,   # <-- replaced text=... with prompt=...
                    tool_config={
                        "function_declarations": self.tools_config,
                        # "AUTO" means the model can produce text or call a function
                        "function_calling_config": {"mode": "AUTO"}
                    },
                    temperature=0.2,      # Adjust for creativity
                    max_output_tokens=512
                )

                return self._process_response(response)

            except Exception as e:
                last_error = str(e)
                logger.warning(f"[call_gemini] Attempt {attempt} failed: {last_error}")

                if attempt < max_retries:
                    logger.info(f"[call_gemini] Retrying in {retry_delay:.1f}s...")
                    await asyncio.sleep(retry_delay)
                    retry_delay *= 2.0  # Exponential backoff
                else:
                    logger.error(f"All attempts failed after {attempt} tries. Last error: {e}")
                    return None
        return None

    def _process_response(self, response: GenerateContentResponse) -> Optional[str]:
        """
        Interprets the GenerateContentResponse object from Gemini.
        If the model calls a tool (function), we dispatch it.
        Otherwise, we collect textual output.
        """
        if not response:
            logger.warning("[_process_response] Empty response object.")
            return None

        if not response.candidates:
            logger.warning("[_process_response] No candidates in response.")
            return None

        aggregated_text = []

        # Iterate over candidate(s)
        for candidate in response.candidates:
            if not candidate.content or not candidate.content.parts:
                continue  # No content parts in this candidate

            for part in candidate.content.parts:
                if part.function_call:
                    fc = part.function_call
                    function_name = fc.name
                    try:
                        args_dict = json.loads(fc.args)
                    except json.JSONDecodeError as ex:
                        logger.error(f"JSON decode error for function args: {ex}")
                        continue

                    logger.info(f"Function call detected: {function_name}")
                    logger.info(f"Arguments: {args_dict}")

                    # Dispatch to local python function
                    fn_result = self.execute_function_call(function_name, args_dict)
                    if fn_result:
                        aggregated_text.append(fn_result)

                elif part.text:
                    # If there's plain text, append it
                    aggregated_text.append(part.text)

        if not aggregated_text:
            logger.info("[_process_response] No text or function calls recognized.")
            return None

        combined = "\n".join(aggregated_text).strip()
        return combined if combined else None

    def execute_function_call(self, function_name: str, args: Dict[str, Any]) -> str:
        """
        Calls the local python function by name, if recognized.
        Otherwise returns an error message.
        """
        if function_name == "generate_file":
            return self._local_generate_file(args)
        elif function_name == "review_code":
            return self._local_review_code(args)
        else:
            logger.warning(f"Unknown function call: {function_name}")
            return f"[execute_function_call] Unknown function '{function_name}'"

    def _local_generate_file(self, args: Dict[str, Any]) -> str:
        """
        Implementation of 'generate_file': create a new .py file with the specified content.
        """
        filename = args.get("filename", "unnamed.py")
        content  = args.get("content", "# empty content")

        logger.info(f"Generating file: {filename}")
        if not filename.endswith(".py"):
            return f"[generate_file] Refused to create non-.py file: {filename}"

        try:
            with open(filename, "w", encoding="utf-8") as f:
                f.write(content)
            msg = f"Successfully created {filename} with content:\n{content}"
            logger.info(msg)
            return msg
        except Exception as e:
            err_msg = f"[generate_file] Error writing {filename}: {str(e)}"
            logger.error(err_msg)
            return err_msg

    def _local_review_code(self, args: Dict[str, Any]) -> str:
        """
        Implementation of 'review_code': Provide style tips or partial refactoring.
        """
        code = args.get("code", "")
        logger.info(f"Reviewing code snippet: {code[:60]}...")

        suggestions = []
        # Basic spacing suggestions
        if "def " in code and '(' in code:
            suggestions.append("- Possibly add docstring or type hints")
        if ",y" in code or "x,y" in code:
            suggestions.append("- Add space after commas in argument lists (PEP 8 style)")
        if "x+y" in code:
            suggestions.append("- Consider spacing around operators: x + y")

        if not suggestions:
            suggestions.append("- Looks fine. Maybe consider docstrings or tests.")

        improved_code = code.replace("x,y", "x, y").replace("x+y", "x + y")
        result = (
            "Code Review:\n" + "\n".join(suggestions) +
            "\n\nSuggested improvements:\n" + improved_code
        )
        return result

###############################################################################
# MAIN (async entry point)
###############################################################################
async def main():
    # Graceful shutdown signals
    def handle_shutdown(signum, frame):
        logger.info("[main] Shutdown signal received. Exiting.")
        exit(0)

    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)

    client = GeminiClient()

    # Some sample prompts:
    test_prompts = [
        "Please tell me a short story about a wise developer building a solution.",
        "Generate_file filename='example.py' content='def hello():\\n    print(\"Hello from generated file\")'",
        "Review_code code='def add(x,y):return x+y'"
    ]

    for i, prompt in enumerate(test_prompts, start=1):
        logger.info("\n" + "="*50)
        logger.info(f"Test {i}/{len(test_prompts)} - Prompt:\n{prompt}")

        start = time.time()
        result = await client.call_gemini(prompt)
        elapsed = time.time() - start

        if result:
            logger.info(f"[main] Gemini returned:\n{result}")
        else:
            logger.warning("[main] No content returned from Gemini (or error).")

        logger.info(f"[main] Duration: {elapsed:.2f}s")

    logger.info("[main] All tests completed.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as e:
        logger.exception("Unexpected error in main:")
