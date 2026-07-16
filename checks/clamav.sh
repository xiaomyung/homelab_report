#!/usr/bin/env bash
# clamav.sh — ClamAV weekly scan summary
#
# Reads:   /var/log/clamav/weekly-scan.log
# Output:  "  ClamAV:    YYYY-MM-DD · N files · N infected"
#          Append " ⚠" if infected > 0.
# Format:  printf "  %-9s  %s%s\n"  (values start at column 13)
# Note:    ClamAV runs weekly — scan date is shown so you know how fresh the data is.
# Test:    sudo bash checks/clamav.sh
# Always exits 0.

set -euo pipefail

LOG="/var/log/clamav/weekly-scan.log"

if [[ ! -f "$LOG" ]]; then
  printf "  %-9s  no scan yet\n" "ClamAV:"
  exit 0
fi

MTIME=$(stat -c %Y "$LOG")
AGE_DAYS=$(( ($(date +%s) - MTIME) / 86400 ))
if [[ $AGE_DAYS -gt 8 ]]; then
  LAST_DATE=$(date -d "@$MTIME" +%Y-%m-%d)
  printf "  %-9s  no recent scan (last: %s, %dd ago) ⚠\n" "ClamAV:" "$LAST_DATE" "$AGE_DAYS"
  exit 0
fi

SUMMARY=$(awk '
  /^=== ClamAV scan/ { buf=$0 "\n"; in_block=1; next }
  in_block            { buf=buf $0 "\n" }
  END                 { printf "%s", buf }
' "$LOG")

SCANNED=$(echo "$SUMMARY" | grep "^Scanned files:" | awk '{print $NF}' || true)
INFECTED=$(echo "$SUMMARY" | grep "^Infected files:" | awk '{print $NF}' || true)
HEADER_DATE=$(echo "$SUMMARY" | grep "^=== ClamAV scan" | sed 's/=== ClamAV scan //; s/ ===//' || true)
# GNU date -d '' succeeds (prints today), so an empty header must be guarded
# explicitly or a garbled log would claim a fresh scan.
if [[ -n "$HEADER_DATE" ]]; then
  SCAN_DATE=$(date -d "$HEADER_DATE" +%Y-%m-%d 2>/dev/null) || SCAN_DATE=$(date -r "$LOG" +%Y-%m-%d)
else
  SCAN_DATE=$(date -r "$LOG" +%Y-%m-%d)
fi

SCANNED=${SCANNED:-unknown}; INFECTED=${INFECTED:-unknown}
VALUE="${SCAN_DATE} · ${SCANNED} files · ${INFECTED} infected"
WARN=""
[[ "$INFECTED" != "0" && "$INFECTED" != "unknown" ]] && WARN=" ⚠"

printf "  %-9s  %s%s\n" "ClamAV:" "$VALUE" "$WARN"
