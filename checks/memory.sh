#!/usr/bin/env bash
# memory.sh — RAM and swap usage
#
# Output:  "  Memory:    RAM 4.2G/15G"
#          "  Memory:    RAM 4.2G/15G · swap 512M/2G ⚠"  (swap ⚠ if >20% used)
# Format:  printf "  %-8s   %s%s\n"  (values start at column 13)
#
# Swap usage is shown only when swap is in use.
# ⚠ when swap usage exceeds 20% of total swap (indicates memory pressure).
#
# Test:    bash checks/memory.sh
# Always exits 0 — never aborts the report.

set -euo pipefail

# free -h output (example):
#               total        used        free      shared  buff/cache   available
# Mem:           15Gi       4.2Gi       8.1Gi       312Mi       3.1Gi        10Gi
# Swap:         2.0Gi          0B       2.0Gi

MEM_LINE=$(free -h | awk 'NR==2')
MEM_USED=$(echo "$MEM_LINE" | awk '{print $3}')
MEM_TOTAL=$(echo "$MEM_LINE" | awk '{print $2}')

SWAP_LINE=$(free -h | awk 'NR==3')
SWAP_USED_H=$(echo "$SWAP_LINE" | awk '{print $3}')
SWAP_TOTAL_H=$(echo "$SWAP_LINE" | awk '{print $2}')

# Raw bytes for threshold calculation
SWAP_USED_KB=$(free | awk 'NR==3 {print $3}')
SWAP_TOTAL_KB=$(free | awk 'NR==3 {print $2}')

VALUE="RAM ${MEM_USED}/${MEM_TOTAL}"
WARN=""

if [[ "${SWAP_USED_KB:-0}" -gt 0 ]]; then
  VALUE="${VALUE} · swap ${SWAP_USED_H}/${SWAP_TOTAL_H}"
  if [[ "${SWAP_TOTAL_KB:-0}" -gt 0 ]]; then
    PCT=$(( SWAP_USED_KB * 100 / SWAP_TOTAL_KB ))
    [[ $PCT -gt 20 ]] && WARN=" ⚠"
  fi
fi

printf "  %-8s   %s%s\n" "Memory:" "$VALUE" "$WARN"
