import os
from typing import Optional, List

MODEL_MAP = {
    "simple": ["gpt-4o-mini-2024-07-18", "gpt-4o-mini"],
    "reasoning": ["o1-mini-2024-09-12", "o1-mini"],
    "complex_generation": ["gpt-4o-2024-08-06", "gpt-4o"],
    "code_generation": ["gpt-4o-2024-08-06", "gpt-4o"],
    "realtime": ["gpt-4o-realtime-preview-2024-12-17", "gpt-4o-realtime-preview"],
    "audio": ["gpt-4o-audio-preview-2024-12-17", "gpt-4o-audio-preview"],
    "image_analysis": ["gpt-4o-2024-08-06", "gpt-4o"],
    "fine_tuning": ["gpt-4o-mini-2024-07-18", "gpt-4o-mini"]
}

def select_model(category: str, available_models: List[str]) -> Optional[str]:
    """Pick best snapshot from MODEL_MAP. Returns None if not found."""
    snapshots = MODEL_MAP.get(category, [])
    for candidate in snapshots:
        if candidate in available_models:
            return candidate
    return None
