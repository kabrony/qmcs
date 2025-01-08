#!/usr/bin/env python3

"""
docker_unified_check.py

A script to:
1) Recursively find Dockerfiles in subdirectories of your qmcs/ folder.
2) For each Dockerfile, check for references to 'main.py' (or other logic).
3) Optionally build and run the Docker image to confirm it starts.
4) Aggregate logs in docker_unified_check.log for a unified view.

You can adjust:
 - DOCKERFILES_GLOB to match your directory structure,
 - MAIN_REFERENCE to check for other file references besides 'main.py'.
"""

import os
import sys
import subprocess
import glob
import re
import datetime

# Directory to scan; adjust if needed
REPO_DIR = "/home/oxdev/qmcs"

# Pattern to find Dockerfiles recursively
DOCKERFILES_GLOB = "**/Dockerfile"

# The string or regex we’re looking for inside Dockerfiles to confirm they reference the "main.py" logic
# (You can broaden this to check for 'CMD ["python", "app.py"]', etc.)
MAIN_REFERENCE = r"(main\.py)"

# If we choose to actually build & run containers, set these to True/False
BUILD_IMAGES = True
RUN_CONTAINERS = True

# We'll unify logs in this file
LOG_FILE = os.path.join(REPO_DIR, "docker_unified_check.log")

def log(message):
    """Log both to stdout and to LOG_FILE."""
    print(message)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"{message}\n")

def run_command(cmd, cwd=None, capture=False):
    """
    Runs a shell command, logs it, optionally returns stdout if capture=True.
    Exits on error.
    """
    log_line = f"[CMD] {' '.join(cmd)} (cwd={cwd or REPO_DIR})"
    log(log_line)
    try:
        if capture:
            result = subprocess.run(
                cmd, cwd=cwd or REPO_DIR, check=True, 
                capture_output=True, text=True
            )
            # Log output
            if result.stdout.strip():
                log("[STDOUT]\n" + result.stdout.strip())
            if result.stderr.strip():
                log("[STDERR]\n" + result.stderr.strip())
            return result.stdout.strip()
        else:
            subprocess.run(cmd, cwd=cwd or REPO_DIR, check=True)
            return None
    except subprocess.CalledProcessError as e:
        log(f"[ERROR] Command failed: {e}")
        sys.exit(1)

def main():
    # Start logging
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log(f"\n=== DOCKER UNIFIED CHECK START: {now} ===")

    # 1) Recursively find Dockerfiles
    pattern = os.path.join(REPO_DIR, DOCKERFILES_GLOB)
    dockerfiles = glob.glob(pattern, recursive=True)

    if not dockerfiles:
        log("[WARN] No Dockerfiles found in the directory structure.")
        return

    for df_path in dockerfiles:
        log(f"\n--- Checking Dockerfile: {df_path} ---")

        # 2) Check if Dockerfile references MAIN_REFERENCE
        try:
            with open(df_path, "r", encoding="utf-8") as f:
                dockerfile_content = f.read()
        except Exception as e:
            log(f"[ERROR] Could not read Dockerfile {df_path}: {e}")
            continue

        # Search for 'main.py' references
        if re.search(MAIN_REFERENCE, dockerfile_content, re.IGNORECASE):
            log(f"[OK] Found reference to '{MAIN_REFERENCE}' in Dockerfile.")
        else:
            log(f"[WARN] No reference to '{MAIN_REFERENCE}' found in {df_path}.")

        # 3) Build image if BUILD_IMAGES
        if BUILD_IMAGES:
            # For image naming, we can derive from subfolder structure
            # e.g. "langchain_demo:latest" or "qmcs-somefolder"
            # We'll do a simple approach: use the path's parent folder name
            df_dir = os.path.dirname(df_path)
            folder_name = os.path.basename(df_dir) or "docker_image"
            image_name = f"qmcs-{folder_name}".lower().replace("_","-")
            log(f"Building image {image_name} for {df_path}...")

            try:
                run_command(["docker", "build", "-t", image_name, "."], cwd=df_dir)
            except Exception as build_err:
                log(f"[ERROR] Build failed for {df_path}: {build_err}")
                continue

            # 4) Optionally run container
            if RUN_CONTAINERS:
                container_name = image_name + "-container"
                # Stop & remove if it exists
                subprocess.run(["docker", "rm", "-f", container_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                log(f"Running container {container_name} from image {image_name}...")

                try:
                    # Run in detached mode, just to see if it starts
                    run_command(["docker", "run", "--rm", "-d", "--name", container_name, image_name])
                    # Sleep a couple seconds or check logs
                    # Attempt logs
                    logs_output = run_command(["docker", "logs", container_name], capture=True)
                    if logs_output:
                        log("[CONTAINER LOGS]\n" + logs_output)

                    # Kill the container
                    run_command(["docker", "stop", container_name])
                except Exception as run_err:
                    log(f"[ERROR] Container run failed for {image_name}: {run_err}")

    end_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log(f"\n=== DOCKER UNIFIED CHECK END: {end_time} ===\n")

if __name__ == "__main__":
    main()
