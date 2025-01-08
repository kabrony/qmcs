#!/usr/bin/env bash
set -e

# Script to display the content of main.py files in specified directories

# Define the directories to search
DIRECTORIES=("openai_service" "argus_service" "oracle_service" "quant_service" "ragchain_service" ".")

# Loop through directories
for dir in "${DIRECTORIES[@]}"; do
  if [[ -d "$dir" ]]; then
    echo "--------------------------------------------------"
    echo "[INFO] Contents of main.py in: $dir"
    if [[ -f "$dir/main.py" ]]; then
      cat "$dir/main.py"
    else
      echo "[ERROR] No main.py found in $dir"
    fi
  else
     if [ "$dir" == "." ]; then
        echo "--------------------------------------------------"
        echo "[INFO] Contents of main.py in the root of the project"
        if [[ -f "main.py" ]]; then
           cat main.py
        else
           echo "[ERROR] No main.py found in the root"
        fi
     else
       echo "[ERROR] Directory '$dir' not found."
     fi

  fi
done

echo "--------------------------------------------------"
echo "[INFO] Done displaying main.py files"

