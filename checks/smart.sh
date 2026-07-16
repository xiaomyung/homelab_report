#!/usr/bin/env bash
# smart.sh — S.M.A.R.T. drive health summary
#
# Reads:   smartctl -H for /dev/sda, /dev/sdb, /dev/nvme0n1
# Output:  "  Drives:    sda OK · sdb OK · nvme0n1 OK"
#          Append ⚠ and mark "FAIL" for any drive reporting FAILED overall health.
#
# /dev/sdb is a USB-connected HDD in the Orico enclosure and requires the
# '-d sat' flag to pass SMART commands through the USB-to-SATA bridge.
#
# Skips drives that don't exist or can't be queried (e.g. /dev/sdb not connected).
#
# Test:    sudo bash checks/smart.sh
# Always exits 0 — never aborts the report.

set -euo pipefail

if ! command -v smartctl &>/dev/null; then
  printf "  %-8s   %s\n" "Drives:" "smartctl not found"
  exit 0
fi

# Drive list: "device [extra smartctl flags]"
DRIVES=(
  "/dev/sda"
  "/dev/sdb -d sat"
  "/dev/nvme0n1"
)

RESULTS=()
ANY_FAIL=false
ANY_UNKNOWN=false

for entry in "${DRIVES[@]}"; do
  dev="${entry%% *}"
  flags="${entry#"$dev"}"
  flags="${flags# }"  # trim leading space

  name=$(basename "$dev")

  # Skip if device node doesn't exist
  [[ -e "$dev" ]] || continue

  # Run smartctl -H; exit code 0=healthy, non-zero=issue or unsupported.
  # -n standby skips (and does not wake) a spun-down drive.
  # Capture output; don't let failure abort the script
  output=$(smartctl -H -n standby $flags "$dev" 2>/dev/null) || true

  if echo "$output" | grep -q "PASSED"; then
    RESULTS+=("${name} OK")
  elif echo "$output" | grep -q "FAILED"; then
    RESULTS+=("${name} FAIL")
    ANY_FAIL=true
  elif echo "$output" | grep -qiE "STANDBY|SLEEP"; then
    # Spun-down disk is normal (idle USB HDD) — not a health problem
    RESULTS+=("${name} standby")
  else
    # Drive exists but SMART status unclear (unsupported, permission issue,
    # dying USB bridge) — worth a ⚠, a health check that can't run is not OK
    RESULTS+=("${name} ?")
    ANY_UNKNOWN=true
  fi
done

if [[ ${#RESULTS[@]} -eq 0 ]]; then
  printf "  %-8s   %s\n" "Drives:" "no drives found"
  exit 0
fi

RESULT_STR=""
for r in "${RESULTS[@]}"; do
  [[ -n "$RESULT_STR" ]] && RESULT_STR+=" · "
  RESULT_STR+="$r"
done

if $ANY_FAIL || $ANY_UNKNOWN; then
  printf "  %-8s   %s %s\n" "Drives:" "$RESULT_STR" "⚠"
else
  printf "  %-8s   %s\n" "Drives:" "$RESULT_STR"
fi
