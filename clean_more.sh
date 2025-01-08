#!/usr/bin/env bash

# Remove known Docker references if they exist and are empty or not used:
rm -f Dockerfile docker-compose.yml docker-compose.yml.bak docker_cleanup.sh
rm -f *Dockerfile* 2>/dev/null

# Remove any docker_unified_check, docker-related logs, or partial references:
rm -f docker_unified_check.log docker_unified_check.py
rm -f fix_container_conflict.log fix_container_conflict.sh

# Optionally remove the entire ARCHIVE folder if you want:
# rm -rf ARCHIVE

# Additional cleanup for .env or settings if they are empty:
[ -s .env ] || rm -f .env

echo "Cleanup done! Now your repo has fewer Docker references or empty .env files."
