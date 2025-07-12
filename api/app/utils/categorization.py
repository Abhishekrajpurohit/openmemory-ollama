import logging
import json
import os
from typing import List

from dotenv import load_dotenv
import ollama
from pydantic import BaseModel
from tenacity import retry, stop_after_attempt, wait_exponential
from app.utils.prompts import MEMORY_CATEGORIZATION_PROMPT

load_dotenv()

# Get Ollama host from environment or use default
OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'http://ollama:11434')
ollama_client = ollama.Client(host=OLLAMA_HOST)


class MemoryCategories(BaseModel):
    categories: List[str]


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=4, max=15))
def get_categories_for_memory(memory: str) -> List[str]:
    try:
        prompt = f"""{MEMORY_CATEGORIZATION_PROMPT}

User input: {memory}

Please respond with a JSON object in this format:
{{"categories": ["category1", "category2", "category3"]}}

Categories should be relevant, concise, and descriptive."""

        # Use Ollama for categorization
        response = ollama_client.generate(
            model="gemma3:1b",
            prompt=prompt,
            format="json",
            options={"temperature": 0}
        )

        # Parse the JSON response
        response_text = response['response'].strip()
        
        # Try to extract JSON from the response
        try:
            response_json = json.loads(response_text)
            categories = response_json.get('categories', [])
        except json.JSONDecodeError:
            # Fallback: try to extract categories from text
            logging.warning(f"Failed to parse JSON, using fallback parsing for: {response_text}")
            categories = []
            # Simple fallback - look for category-like words
            for line in response_text.split('\n'):
                if line.strip() and not line.startswith('#'):
                    categories.append(line.strip().strip('"-.,'))
        
        # Clean and return categories
        return [cat.strip().lower() for cat in categories if cat.strip()]

    except Exception as e:
        logging.error(f"[ERROR] Failed to get categories: {e}")
        # Return default categories as fallback
        return ["general", "personal"]
