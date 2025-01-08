#!/bin/bash

# Set up a virtual environment
if ! command -v python3 &>/dev/null; then
    echo "Python 3 is not installed. Please install it."
    exit 1
fi

if ! command -v python3-venv &>/dev/null; then
    sudo apt update
    sudo apt install python3-venv -y
fi

VENV_DIR="venv"

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv $VENV_DIR
else
    echo "Virtual environment already exists."
fi

# Activate the virtual environment
source "$VENV_DIR/bin/activate"

# Install dependencies
if [ -f "requirements.txt" ]; then
    echo "Installing dependencies from requirements.txt..."
    pip install -r requirements.txt
else
    echo "No requirements.txt found. Skipping dependency installation."
fi

# Run the Python script
echo "Running the enhanced autonomous system..."
python enhanced_autonomous.py

deactivate
