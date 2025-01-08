#!/usr/bin/env python3

"""
daily_repo_maintenance.py

A Python script for daily repository maintenance:
1) Pull/merge from upstream (e.g., sendaifun/solana-agent-kit).
2) Rebuild Docker images if needed.
3) Optionally run tests.
4) Commit & push any local changes (like updated docs) back to your fork.
5) Write logs to daily_repo_maintenance.log.

Schedule via cron, for example:
  0 3 * * * /home/oxdev/qmcs/daily_repo_maintenance.py >> /home/oxdev/qmcs/logs/daily_repo_maintenance.log 2>&1
"""

import os
import subprocess
import datetime
import sys

# Paths (adjust to your local setup)
REPO_DIR = "/home/oxdev/qmcs"           # Path to your local 'qmcs' folder
UPSTREAM_REMOTE = "upstream"            # Remote name for upstream
UPSTREAM_BRANCH = "main"                # The upstream branch you track
ORIGIN_REMOTE = "origin"                # Your fork's remote name
LOCAL_BRANCH = "main"                   # Your local branch
DOCKER_COMPOSE_FILE = "docker-compose.yml"  # If using docker-compose

# Optional: If you have a test command or script
TEST_COMMAND = ["python", "-m", "unittest", "discover", "tests"]

# Log file
LOG_FILE = os.path.join(REPO_DIR, "daily_repo_maintenance.log")


def run_command(cmd, cwd=None):
    """
    Utility to run shell commands and log output.
    """
    log_line = f"Running: {' '.join(cmd)} in {cwd or REPO_DIR}"
    print(log_line)
    with open(LOG_FILE, "a") as f:
        f.write(f"{log_line}\n")

    try:
        result = subprocess.run(cmd, cwd=cwd or REPO_DIR, check=True, capture_output=True, text=True)
        output = result.stdout
        error = result.stderr
        with open(LOG_FILE, "a") as f:
            if output:
                f.write(f"STDOUT:\n{output}\n")
            if error:
                f.write(f"STDERR:\n{error}\n")
    except subprocess.CalledProcessError as e:
        # Log the error and exit or continue based on your preference
        with open(LOG_FILE, "a") as f:
            f.write(f"[ERROR] Command failed: {e}\n")
            f.write(f"STDOUT:\n{e.stdout}\nSTDERR:\n{e.stderr}\n")
        sys.exit(1)


def main():
    # 1) Start logging
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"\n===== DAILY REPO MAINTENANCE START: {now} =====\n")

    # 2) Ensure we’re on local main branch
    run_command(["git", "checkout", LOCAL_BRANCH])

    # 3) Pull from upstream
    run_command(["git", "fetch", UPSTREAM_REMOTE])
    run_command(["git", "merge", f"{UPSTREAM_REMOTE}/{UPSTREAM_BRANCH}"])

    # 4) Optionally rebuild Docker images if you have a docker-compose file
    if os.path.isfile(os.path.join(REPO_DIR, DOCKER_COMPOSE_FILE)):
        run_command(["docker-compose", "build", "--no-cache"])

    # 5) (Optional) Run tests
    # If you prefer a custom test script, adjust TEST_COMMAND accordingly.
    # If no tests, comment out the following block:
    if TEST_COMMAND:
        run_command(TEST_COMMAND)

    # 6) Check if there are any changes to commit (like updated docs, scripts, etc.)
    run_command(["git", "add", "-A"])
    # Determine if there's anything to commit
    diff_check = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=REPO_DIR)
    if diff_check.returncode == 1:
        # 7) Commit & push changes to your fork
        commit_msg = f"Daily maintenance auto-update: {now}"
        run_command(["git", "commit", "-m", commit_msg])
        run_command(["git", "push", ORIGIN_REMOTE, LOCAL_BRANCH])
    else:
        with open(LOG_FILE, "a") as f:
            f.write("No changes to commit.\n")

    # 8) Finish logging
    end_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"===== DAILY REPO MAINTENANCE END: {end_time} =====\n\n")


if __name__ == "__main__":
    main()
