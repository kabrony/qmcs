#!/usr/bin/env python3

"""
master_maintenance_script.py

A single “master” script that performs daily maintenance tasks:
 1) Pull & merge from upstream (e.g., sendaifun/solana-agent-kit).
 2) (Optional) Rebuild Docker images if docker-compose.yml is present.
 3) (Optional) Run tests to ensure everything is stable.
 4) Commit & push any changes (docs, scripts, etc.) to your fork.
 5) Log everything to master_maintenance_script.log

After creating it, you can run:
  ./master_maintenance_script.py

And optionally schedule with cron, e.g.:
  0 2 * * * /path/to/master_maintenance_script.py >> /path/to/master_maintenance_script_cron.log 2>&1
"""

import os
import subprocess
import sys
import datetime

# Adjust these paths and names to match your environment
REPO_DIR = "/home/oxdev/qmcs"          # Path to your local 'qmcs' folder
UPSTREAM_REMOTE = "upstream"           # The upstream remote name
UPSTREAM_BRANCH = "main"               # The upstream branch (e.g., 'main')
ORIGIN_REMOTE = "origin"               # Your fork's remote name
LOCAL_BRANCH = "main"                  # Your local branch name
DOCKER_COMPOSE_FILE = "docker-compose.yml"  # If you have a docker-compose file
TEST_COMMAND = ["python", "-m", "unittest", "discover", "tests"]  # If you have tests
LOG_FILE = os.path.join(REPO_DIR, "master_maintenance_script.log")

def run_command(cmd, cwd=None):
    """
    Utility to run shell commands and log output to LOG_FILE and stdout.
    """
    command_str = " ".join(cmd)
    log_line = f"Running: {command_str} (cwd: {cwd or REPO_DIR})"
    print(log_line)
    with open(LOG_FILE, "a") as f:
        f.write(f"{log_line}\n")

    try:
        result = subprocess.run(cmd, cwd=cwd or REPO_DIR, check=True, capture_output=True, text=True)
        output = result.stdout.strip()
        error = result.stderr.strip()
        if output:
            print(output)
        if error:
            print(error, file=sys.stderr)
        with open(LOG_FILE, "a") as f:
            if output:
                f.write(f"STDOUT:\n{output}\n")
            if error:
                f.write(f"STDERR:\n{error}\n")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Command failed: {cmd}", file=sys.stderr)
        with open(LOG_FILE, "a") as f:
            f.write(f"[ERROR] Command failed: {e}\n")
            if e.stdout:
                f.write(f"STDOUT:\n{e.stdout}\n")
            if e.stderr:
                f.write(f"STDERR:\n{e.stderr}\n")
        sys.exit(1)

def main():
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"\n===== MASTER MAINTENANCE START: {now} =====\n")

    # 1) Switch to local branch
    run_command(["git", "checkout", LOCAL_BRANCH])

    # 2) Pull from upstream
    run_command(["git", "fetch", UPSTREAM_REMOTE])
    run_command(["git", "merge", f"{UPSTREAM_REMOTE}/{UPSTREAM_BRANCH}"])

    # 3) (Optional) Rebuild Docker images if docker-compose exists
    docker_compose_path = os.path.join(REPO_DIR, DOCKER_COMPOSE_FILE)
    if os.path.isfile(docker_compose_path):
        run_command(["docker-compose", "build", "--no-cache"])

    # 4) (Optional) Run tests
    # If no tests, comment out the next lines
    if TEST_COMMAND:
        run_command(TEST_COMMAND)

    # 5) Check if any changes to commit
    run_command(["git", "add", "-A"])
    diff_check = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=REPO_DIR)

    if diff_check.returncode == 1:
        commit_msg = f"Auto-update from master maintenance script: {now}"
        run_command(["git", "commit", "-m", commit_msg])
        run_command(["git", "push", ORIGIN_REMOTE, LOCAL_BRANCH])
    else:
        print("No changes to commit.")
        with open(LOG_FILE, "a") as f:
            f.write("No changes to commit.\n")

    end_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"===== MASTER MAINTENANCE END: {end_time} =====\n\n")

if __name__ == "__main__":
    main()
