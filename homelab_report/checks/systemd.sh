#!/usr/bin/env bash
# systemd.sh — Failed systemd units
#
# Reads:   systemctl --failed
# Output:  Nothing if no units are failed (section omitted from report).
#          "  Systemd:   N failed (unit1.service, unit2.service) ⚠" if any are failed.
#
# Test:    bash checks/systemd.sh
# Always exits 0 — never aborts the report.

set -euo pipefail

# --no-legend strips the header/footer lines; --plain gives clean output
FAILED=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}') || true

if [[ -z "$FAILED" ]]; then
  # Output nothing — report.sh omits this line when empty
  exit 0
fi

COUNT=$(echo "$FAILED" | wc -l)
NAMES=$(echo "$FAILED" | paste -sd ', ')
printf "  %-8s   %s %s\n" "Systemd:" "${COUNT} failed (${NAMES})" "⚠"
