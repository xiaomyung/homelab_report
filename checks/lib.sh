#!/usr/bin/env bash
# lib.sh — helpers shared by check scripts. Source, don't execute:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# stale_guard <log> <max_age_days> <label>
# Guards log-based checks against silently reporting stale data. When <log>'s
# mtime is older than <max_age_days>, prints the standard warning line
#   "  <label>    no recent run (last: YYYY-MM-DD, Nd ago) ⚠"
# and returns 1 so the caller can `stale_guard ... || exit 0`.
# Returns 0 (silently) when the log is fresh.
stale_guard() {
  local log="$1" max_days="$2" label="$3"
  local mtime age_days
  mtime=$(stat -c %Y "$log")
  age_days=$(( ($(date +%s) - mtime) / 86400 ))
  if (( age_days > max_days )); then
    printf "  %-9s  no recent run (last: %s, %dd ago) ⚠\n" \
      "$label" "$(date -d "@$mtime" +%Y-%m-%d)" "$age_days"
    return 1
  fi
}
