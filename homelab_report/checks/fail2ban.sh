#!/usr/bin/env bash
# fail2ban.sh — fail2ban jail status summary
#
# Reads:   fail2ban-client status (live)
# Output:  "  fail2ban:  N jail(s) · N banned"
#          "  fail2ban:  not running ⚠"   (installed but service down)
#          (no output if fail2ban is not installed)
# Format:  printf "  %-9s  %s%s\n"  (values start at column 13)
#
# Bans are normal operation — no ⚠ for bans. ⚠ only if the service itself is down.
#
# Test:    sudo bash checks/fail2ban.sh
# Always exits 0 — never aborts the report.

set -euo pipefail

if ! command -v fail2ban-client &>/dev/null; then
  # Not installed — output nothing; omit from report
  exit 0
fi

# Check if the service is responding
STATUS=$(fail2ban-client status 2>/dev/null) || {
  printf "  %-9s  %s %s\n" "fail2ban:" "not running" "⚠"
  exit 0
}

# Parse jail list: "Jail list:	sshd, nginx-http-auth"
JAIL_LIST=$(echo "$STATUS" | grep "Jail list:" | sed 's/.*Jail list://; s/\t//g; s/  */ /g; s/^ //')
JAIL_COUNT=$(echo "$JAIL_LIST" | tr ',' '\n' | grep -c '[a-z]' || true)
JAIL_COUNT=${JAIL_COUNT:-0}

if [[ "$JAIL_COUNT" -eq 0 ]]; then
  printf "  %-9s  %s\n" "fail2ban:" "0 jails active"
  exit 0
fi

# Sum currently banned IPs across all jails
TOTAL_BANNED=0
while IFS=', ' read -r jail; do
  [[ -z "$jail" ]] && continue
  BANNED=$(fail2ban-client status "$jail" 2>/dev/null \
    | grep "Currently banned:" | awk '{print $NF}' || true)
  TOTAL_BANNED=$(( TOTAL_BANNED + ${BANNED:-0} ))
done <<< "$(echo "$JAIL_LIST" | tr ',' '\n' | sed 's/^ //; s/ $//')"

printf "  %-9s  %s\n" "fail2ban:" "${JAIL_COUNT} jail(s) · ${TOTAL_BANNED} banned"
