#!/usr/bin/env python3

"""
daily_oracle_maintenance.py

A modified “master” maintenance script that:
1) Does the usual repo maintenance (pull, merge, etc.).
2) Sends a summary of the run (success/fail) to a VOTS dashboard endpoint, 
   so your Oracle or MainBrain agent can display it.
"""

import os
import subprocess
import sys
import datetime
import requests  # If you have requests installed; otherwise, use another HTTP library

REPO_DIR = "/home/oxdev/qmcs"
UPSTREAM_REMOTE = "upstream"
UPSTREAM_BRANCH = "main"
ORIGIN_REMOTE = "origin"
LOCAL_BRANCH = "main"
DOCKER_COMPOSE_FILE = "docker-compose.yml"
TEST_COMMAND = ["python", "-m", "unittest", "discover", "tests"]
LOG_FILE = os.path.join(REPO_DIR, "master_maintenance_script.log")

# Example VOTS dashboard endpoint
VOTS_DASHBOARD_URL = "https://vots-dashboard.example.com/api/maintenance-report"

def run_command(cmd, cwd=None):
    """
    Utility function that runs shell commands, logs them, 
    and captures output in master_maintenance_script.log
    """
    command_str = " ".join(cmd)
    with open(LOG_FILE, "a") as f:
        f.write(f"[CMD] {command_str}\n")

    try:
        result = subprocess.run(cmd, cwd=cwd or REPO_DIR, check=True, capture_output=True, text=True)
        output = result.stdout.strip()
        error = result.stderr.strip()
        with open(LOG_FILE, "a") as f:
            if output:
                f.write(f"[STDOUT]\n{output}\n")
            if error:
                f.write(f"[STDERR]\n{error}\n")
    except subprocess.CalledProcessError as e:
        with open(LOG_FILE, "a") as f:
            f.write(f"[ERROR] {e}\n")
            if e.stdout:
                f.write(f"STDOUT:\n{e.stdout}\n")
            if e.stderr:
                f.write(f"STDERR:\n{e.stderr}\n")
        # Re-raise to stop script
        raise

def main():
    # We'll track success/failure in a boolean
    success = True
    error_message = ""

    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"\n=== ORACLE/ARCHITECT DAILY MAINTENANCE START: {now_str} ===\n")

    try:
        # 1) Checkout local branch
        run_command(["git", "checkout", LOCAL_BRANCH])
        # 2) Pull & merge from upstream
        run_command(["git", "fetch", UPSTREAM_REMOTE])
        run_command(["git", "merge", f"{UPSTREAM_REMOTE}/{UPSTREAM_BRANCH}"])

        # 3) Optional Docker rebuild
        docker_compose_path = os.path.join(REPO_DIR, DOCKER_COMPOSE_FILE)
        if os.path.isfile(docker_compose_path):
            run_command(["docker-compose", "build", "--no-cache"])

        # 4) (Optional) run tests
        if TEST_COMMAND:
            run_command(TEST_COMMAND)

        # 5) Check for changes
        run_command(["git", "add", "-A"])
        diff_check = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=REPO_DIR)
        if diff_check.returncode == 1:
            commit_msg = f"Oracle Maintenance Auto-Update {now_str}"
            run_command(["git", "commit", "-m", commit_msg])
            run_command(["git", "push", ORIGIN_REMOTE, LOCAL_BRANCH])
        else:
            with open(LOG_FILE, "a") as f:
                f.write("No changes to commit.\n")

    except Exception as e:
        success = False
        error_message = str(e)

    end_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"=== ORACLE/ARCHITECT DAILY MAINTENANCE END: {end_str} ===\n\n")

    # READ last lines of the log for summary
    summary_tail = "[No summary]"
    try:
        with open(LOG_FILE, "r") as lf:
            logs = lf.read().splitlines()
            # Grab last ~10 lines or so
            summary_tail = "\n".join(logs[-10:])
    except:
        pass

    # 6) Send results to VOTS dashboard
    # If you need an auth token, you'd do requests.post with headers, etc.
    payload = {
        "timestamp": now_str,
        "success": success,
        "error_message": error_message,
        "log_summary": summary_tail,
    }
    try:
        resp = requests.post(VOTS_DASHBOARD_URL, json=payload, timeout=15)
        # Optionally log the response
        with open(LOG_FILE, "a") as f:
            f.write(f"[VOTS-DASHBOARD] POST {VOTS_DASHBOARD_URL} => {resp.status_code}\n")
    except Exception as post_err:
        with open(LOG_FILE, "a") as f:
            f.write(f"[VOTS-DASHBOARD ERROR] {str(post_err)}\n")

if __name__ == "__main__":
    main()
