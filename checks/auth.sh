#!/usr/bin/env bash
# auth.sh — SSH authentication failure count in the last 24 hours
#
# Reads:   /var/log/auth.log
# Output:  "  SSH auth:  last 24h · 0 failure(s)"
#          "  SSH auth:  last 24h · N failure(s) ⚠"
#          "  SSH auth:  no log found"
# Format:  printf "  %-9s  %s%s\n"  (values start at column 13)
#
# Uses a rolling 24-hour window. auth.log timestamps have no year ("Mar 29
# 10:30:00"), so entries from today and yesterday are checked and filtered
# by epoch comparison.
#
# Test:    sudo bash checks/auth.sh
# Always exits 0 — never aborts the report.

set -euo pipefail

LOG="/var/log/auth.log"

if [[ ! -f "$LOG" ]]; then
  printf "  %-9s  %s\n" "SSH auth:" "no log found"
  exit 0
fi

CUTOFF=$(date -d '24 hours ago' +%s)
TODAY=$(date +'%b %e')
YESTERDAY=$(date -d 'yesterday' +'%b %e')

FAIL_COUNT=$(grep -E "^($TODAY|$YESTERDAY)" "$LOG" 2>/dev/null \
  | grep -E "Failed password|Invalid user|authentication failure" \
  | while IFS= read -r line; do
      TS=$(echo "$line" | awk '{print $1, $2, $3}')
      TS_EPOCH=$(date -d "$TS" +%s 2>/dev/null) || continue
      [[ "$TS_EPOCH" -ge "$CUTOFF" ]] && echo "$line"
    done \
  | wc -l \
  || true)
FAIL_COUNT=${FAIL_COUNT:-0}

WARN=""
[[ "$FAIL_COUNT" -gt 0 ]] && WARN=" ⚠"

printf "  %-9s  %s%s\n" "SSH auth:" "last 24h · ${FAIL_COUNT} failure(s)" "$WARN"
