#!/usr/bin/env bash
#
# reinstall_openai.sh
# Uninstalls any existing openai library and installs the latest version.
# Also performs a minimal test script to ensure the new library works.
#

set -e  # Exit on error

# 1) (Optional) Deactivate + Reactivate your venv
echo "Deactivating & reactivating venv if you have it. If you don't, ignore errors."
deactivate 2>/dev/null || true
source venv/bin/activate 2>/dev/null || true

# 2) Uninstall existing openai
echo ">>> Uninstalling old openai (if any) ..."
pip uninstall -y openai || true

# 3) Install latest openai
echo ">>> Installing latest openai..."
pip install --no-cache-dir --upgrade openai

# 4) Check installed version
echo ">>> Checking installed openai version..."
pip show openai || true

# 5) Create a minimal test script
cat << 'TESTEOF' > test_openai.py
import os
import openai

openai.api_key = os.getenv("OPENAI_API_KEY")

try:
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": "Hello from the new library!"}]
    )
    print(resp.choices[0].message.content)
except Exception as e:
    print(f"Error: {e}")
TESTEOF

# 6) Run the minimal test
echo ">>> Running test_openai.py. If it works, you'll see a normal model response."
python test_openai.py

echo ">>> Done! If no error about 'You tried to access openai.ChatCompletion...' is shown, you're all set."
