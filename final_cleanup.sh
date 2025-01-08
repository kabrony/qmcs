#!/usr/bin/env bash

# Move leftover log/artifact files to ARCHIVE or remove them
mv all_in_one_debug.s ARCHIVE/ 2>/dev/null
mv all_in_one_debug_report.txt ARCHIVE/ 2>/dev/null
mv *.log ARCHIVE/ 2>/dev/null
mv *.bak ARCHIVE/ 2>/dev/null
mv full_file_dump.txt ARCHIVE/ 2>/dev/null
mv full_report.txt ARCHIVE/ 2>/dev/null
mv full_system_report.txt ARCHIVE/ 2>/dev/null
mv ragchain_*report_*.log ARCHIVE/ 2>/dev/null

# Remove old env backups if not needed
rm -f .env_backup_2025*

# If you don’t need “If” or bracket-named 0-byte placeholders:
rm -f "If"
rm -f "[Error]"
rm -f "[quant_service"
rm -f "[quant_service]"
rm -f "[ragchain_service"
rm -f "[ragchain_service]"

# Optionally remove all zero-byte files
find . -type f -size 0 -print -exec rm -f {} \;

echo "Final cleanup done! Check ARCHIVE/ for moved items."
