#!/usr/bin/env bash
# logins.sh — Successful SSH/console logins in the last 24 hours
#
# Reads:   /var/log/wtmp via `last`
# Output:  "  Logins:    none in last 24h"
#          "  Logins:    2 in last 24h"
#          "             apollo from 192.168.1.10 at 03-28, last 10:30, (2)"
#          "             root at 03-27, last 22:15, (1) (local)"
# Format:  printf "  %-8s   %s\n" for the count line;
#          13-space indent for each login entry.
#
# Uses a rolling 24-hour window so cross-midnight sessions are counted
# by their actual login time, not by calendar day.
#
# last --time-format iso field layout:
#   With source IP:  user  tty  source  login-time  [- logout-time (dur)]
#   Without source:  user  tty  login-time  [- logout-time (dur)]
# Disambiguated by whether field 3 has the ISO-timestamp shape (a bare
# 'T' check would misparse hostnames containing a T).
#
# Test:    bash checks/logins.sh
# Always exits 0 — never aborts the report.

set -euo pipefail

CUTOFF=$(date -d '24 hours ago' +%s)
# 13 spaces — aligns under value column (2 + 8 label + 3 sep)
INDENT="             "

# Filter `last` output down to pre-parsed in-window records, one per line:
#   user|source|MM-DD|HH:MM
# source is empty for local/no-source logins. A single `date` call per line
# yields both the epoch (window filter) and the display date/time.
RECORDS=$(last --time-format iso 2>/dev/null \
  | grep -vE "^reboot|^wtmp" \
  | while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      read -r user _ f3 f4 _ <<< "$line"
      if [[ "$f3" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
        src=""; ts="$f3"
      else
        src="$f3"; ts="$f4"
      fi
      [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]] || continue
      out=$(date -d "$ts" '+%s %m-%d %H:%M' 2>/dev/null) || continue
      read -r epoch dt tm <<< "$out"
      [[ "$epoch" -ge "$CUTOFF" ]] && printf '%s|%s|%s|%s\n' "$user" "$src" "$dt" "$tm"
    done \
  || true)

COUNT=$(grep -c '|' <<< "$RECORDS" || true)
COUNT=${COUNT:-0}

if [[ "$COUNT" -eq 0 ]]; then
  printf "  %-8s   %s\n" "Logins:" "none in last 24h"
  exit 0
fi

printf "  %-8s   %s\n" "Logins:" "${COUNT} in last 24h"

# Group by user+source+date; records are newest-first, so the first time
# seen per group is that group's most recent login.
declare -A counts
declare -A latest
declare -a order

while IFS='|' read -r user src dt tm; do
  [[ -z "$user" ]] && continue
  KEY="${user}|${src}|${dt}"
  if [[ -z "${counts[$KEY]+x}" ]]; then
    order+=("$KEY")
    counts[$KEY]=0
    latest[$KEY]="$tm"
  fi
  counts[$KEY]=$(( counts[$KEY] + 1 ))
done <<< "$RECORDS"

mapfile -t sorted_keys < <(
  for KEY in "${order[@]}"; do
    IFS='|' read -r u src dt <<< "$KEY"
    echo "${counts[$KEY]}|${dt}|${KEY}"
  done | sort -t'|' -k1,1rn -k2,2r | awk -F'|' '{print $3"|"$4"|"$5}'
)

for KEY in "${sorted_keys[@]}"; do
  IFS='|' read -r u src dt <<< "$KEY"
  CNT=${counts[$KEY]}
  LT=${latest[$KEY]}
  if [[ -z "$src" ]]; then
    printf "%s%s at %s, last %s, (%s) (local)\n"   "$INDENT" "$u" "$dt" "$LT" "$CNT"
  elif [[ "$src" =~ ^(:[0-9]|tty|pts) ]]; then
    printf "%s%s at %s, last %s, (%s) (console)\n" "$INDENT" "$u" "$dt" "$LT" "$CNT"
  else
    printf "%s%s from %s at %s, last %s, (%s)\n"   "$INDENT" "$u" "$src" "$dt" "$LT" "$CNT"
  fi
done
