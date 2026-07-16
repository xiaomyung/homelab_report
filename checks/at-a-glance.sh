#!/usr/bin/env bash
# at-a-glance.sh — Anomaly summary of the main report (⚠-line extraction)
#
# Reads:   the HTML-stripped main report on stdin
# Output:  "✅ All clear" when no line carries the ⚠ marker,
#          one "• ..." bullet per ⚠-tagged line otherwise,
#          or "⚠️ Summary unavailable (empty input)" if stdin is empty
# Test:    printf '  AIDE:  1 added ⚠\n' | bash checks/at-a-glance.sh
# Always exits 0 — never aborts the report.
#
# The check scripts have already decided what is anomalous: every problem
# line they emit ends with the ⚠ character. This script only surfaces those
# lines as bullets — no interpretation, no external dependencies.

set -euo pipefail

REPORT=$(cat)

if [[ -z "$REPORT" ]]; then
  # Distinct from "✅ All clear" so a plumbing break stays visible.
  echo "⚠️ Summary unavailable (empty input)"
  exit 0
fi

awk '
  # Remember the label of the current value line ("Docker:") so continuation
  # lines ("             crashed: ... ⚠") can be attributed to it.
  /^  [^ ]/ { label = $1 }

  /⚠[[:space:]]*$/ {
    cont = ($0 ~ /^    /)              # deeper indent = continuation line
    gsub(/[[:space:]]*⚠[[:space:]]*$/, "")
    gsub(/[[:space:]]+/, " ")
    sub(/^ /, "")
    print "• " (cont ? label " " : "") $0
    bullets++
  }

  END { if (!bullets) print "✅ All clear" }
' <<< "$REPORT"

exit 0
