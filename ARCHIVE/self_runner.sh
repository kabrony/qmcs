#!/usr/bin/env bash
#
# self_runner.sh
# A script that executes itself exactly once more, then stops.

# If we haven’t set SELF_RERUN, set it and rerun.
if [ -z "$SELF_RERUN" ]; then
  echo "[self_runner.sh] First run. Will rerun myself..."
  export SELF_RERUN=1
  # Rerun the same script with the same args
  exec "$0" "$@"
fi

# If we reach here, SELF_RERUN is set -> second run
echo "[self_runner.sh] Second run: done. Not rerunning again."

