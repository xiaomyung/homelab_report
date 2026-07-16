#!/usr/bin/env bash
# rkhunter.sh — Rootkit Hunter daily check summary
#
# Reads:   /var/log/rkhunter.log
# Output:  "  rkhunter:  YYYY-MM-DD · all clear"
#          "  rkhunter:  YYYY-MM-DD · N warning(s) ⚠"
# Format:  printf "  %-9s  %s\n"  (values start at column 13)
#
# Debian's daily cron runs rkhunter with --appendlog, so the log accumulates
# every past run. Warnings are counted only for the LAST run (the counter
# resets on each "Start date is" boundary line); the scan date comes from
# that same boundary line, falling back to the log's mtime.
#
# Test:    sudo bash checks/rkhunter.sh
# Always exits 0.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOG="/var/log/rkhunter.log"

if [[ ! -f "$LOG" ]]; then
  printf "  %-9s  no log found\n" "rkhunter:"
  exit 0
fi

stale_guard "$LOG" 2 "rkhunter:" || exit 0

# [ Warning ] is rkhunter's single marker for ALL problems — suspicious files,
# rootkit signatures, infected binaries, config issues. Everything bad is a warning.
WARNING_COUNT=$(awk '/Info: Start date is/{c=0} /\[ Warning \]/{c++} END{print c+0}' "$LOG")

START_STR=$(grep 'Info: Start date is' "$LOG" | tail -1 | sed 's/.*Start date is //' || true)
if [[ -n "$START_STR" ]]; then
  SCAN_DATE=$(date -d "$START_STR" +%F 2>/dev/null) || SCAN_DATE=$(date -r "$LOG" +%F)
else
  SCAN_DATE=$(date -r "$LOG" +%F)
fi

if [[ "$WARNING_COUNT" -eq 0 ]]; then
  VALUE="${SCAN_DATE} · all clear"
else
  VALUE="${SCAN_DATE} · ${WARNING_COUNT} warning(s) ⚠"
fi

printf "  %-9s  %s\n" "rkhunter:" "$VALUE"
