#!/usr/bin/env bash
# auth.sh — SSH authentication failure count in the last 24 hours
#
# Reads:   /var/log/auth.log
# Output:  "  SSH auth:  last 24h · 0 failure(s)"
#          "  SSH auth:  last 24h · N failure(s) ⚠"
#          "  SSH auth:  no log found"
# Format:  printf "  %-9s  %s%s\n"  (values start at column 13)
#
# Uses a rolling 24-hour window. auth.log lines carry RFC3339 timestamps
# ("2026-07-16T12:04:05.620767+03:00 host sshd-session[123]: ..."), so lines
# from today and yesterday are pre-filtered by date prefix, then their
# timestamps are batch-converted to epoch with one `date -f -` call and
# compared against the cutoff. Only sshd lines are counted (the process is
# named sshd-session on Debian 13, sshd on older releases).
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
TODAY=$(date +%F)
YESTERDAY=$(date -d yesterday +%F)

FAIL_COUNT=$(
  grep -E "^($TODAY|$YESTERDAY)T" "$LOG" 2>/dev/null \
    | grep -E 'sshd[^ ]*\[[0-9]+\]:' \
    | grep -E "Failed password|Invalid user|authentication failure" \
    | awk '{print $1}' \
    | date -f - +%s 2>/dev/null \
    | awk -v cutoff="$CUTOFF" '$0+0 >= cutoff+0' \
    | wc -l \
    || true
)
FAIL_COUNT=${FAIL_COUNT:-0}

WARN=""
[[ "$FAIL_COUNT" -gt 0 ]] && WARN=" ⚠"

printf "  %-9s  %s%s\n" "SSH auth:" "last 24h · ${FAIL_COUNT} failure(s)" "$WARN"
