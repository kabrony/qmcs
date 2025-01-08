#!/bin/bash

# --- Define log file names ---
MEMORY_FILE="/home/oxdev/qmcs/python-genai/advanced_memory.json"
INTERACTION_LOG="/home/oxdev/qmcs/python-genai/interaction_log.jsonl"
TRAINING_LOG="/home/oxdev/qmcs/python-genai/training_log.txt" # New training log file

# --- Memory Log Output ---
echo "--------------------------------------------"
echo "---------- Memory Log Contents -------------"
echo "--------------------------------------------"

if [ -f "$MEMORY_FILE" ]; then
  if jq -e '.' "$MEMORY_FILE" > /dev/null 2>&1; then
    jq '.' "$MEMORY_FILE" | less # use less to avoid overflowing the screen
  else
    echo "  Error: $MEMORY_FILE contains invalid JSON."
  fi
else
  echo "  Error: Memory log file ($MEMORY_FILE) not found."
fi

# --- Interaction Log Output ---
echo "--------------------------------------------"
echo "---------- Interaction Log (Recent) ---------"
echo "--------------------------------------------"

if [ -f "$INTERACTION_LOG" ]; then
  tail -n 20 "$INTERACTION_LOG" | less # show last 20 lines use less
else
    echo "  Error: Interaction log file ($INTERACTION_LOG) not found."
fi


# --- Training Log Output ---
echo "--------------------------------------------"
echo "---------- Training Log (Recent) -----------"
echo "--------------------------------------------"
if [ -f "$TRAINING_LOG" ]; then
  tail -n 20 "$TRAINING_LOG" | less  # show last 20 lines use less
else
    echo "  Error: Training log file ($TRAINING_LOG) not found."
fi


echo "--------------------------------------------"
echo "-------- End of Log Information -----------"
echo "--------------------------------------------"
