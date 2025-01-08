#!/usr/bin/env python3
import os
import logging
import google.generativeai as genai

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def main():
    logger.info("Starting basic Gemini test...")
    
    if not os.getenv("GEMINI_API_KEY"):
        logger.error("GEMINI_API_KEY not set")
        exit(1)
        
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel("gemini-pro")

    try:
        response = model.generate_content("Tell me a short story.")
        logger.info("Response received successfully")
        logger.info(f"Response type: {type(response)}")
        logger.info(f"Response attributes: {dir(response)}")
        logger.info(f"Response text: {response.text}")
    except Exception as e:
        logger.error(f"Error during Gemini call: {str(e)}")
        logger.exception("Full traceback:")

if __name__ == "__main__":
    main()
