#!/usr/bin/env bash
# disk.sh — Disk usage on key mount points
#
# Reads:   df -h (live)
# Output:  "  /path:          N% used (of SIZE)"
#          Append " ⚠" if usage >= 85%.
# Format:  printf "  %-13s  %s%s\n"  (values start at column 17)
#          /mnt/storage: is 13 chars — the longest path label.
# Test:    bash checks/disk.sh
# Always exits 0.

set -euo pipefail

# / is always shown; the /mnt/* paths are skipped when not mounted
PATHS=("/" "/mnt/storage" "/mnt/cloud")

check_path() {
  local path="$1"
  if [[ "$path" != "/" ]] && ! mountpoint -q "$path" 2>/dev/null; then
    return 0
  fi
  # -P (POSIX format) prevents line-wrapping on long device names
  local info
  info=$(df -Ph "$path" 2>/dev/null | awk 'NR==2 {print $5, $2}') || return 0
  local pct="${info%% *}"
  local size="${info##* }"
  local pct_num="${pct%%%}"
  [[ "$pct_num" =~ ^[0-9]+$ ]] || return 0
  local warn=""
  [[ "$pct_num" -ge 85 ]] && warn=" ⚠"
  printf "  %-13s  %s%s\n" "${path}:" "${pct} used (of ${size})" "$warn"
}

for p in "${PATHS[@]}"; do check_path "$p"; done
