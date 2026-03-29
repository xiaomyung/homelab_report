#!/usr/bin/env bash
# backup.sh — server-backup.sh and recovery-snapshot.sh result summary
#
# Reads:
#   /var/log/server-backup-cron.log   — full system backup log (world-readable)
#   /var/log/recovery-snapshot.log    — bare-metal recovery snapshot log (root-readable)
#
# Output (two lines):
#   "  Backup:    YYYY-MM-DD HH:MM · ✓ SIZE · local+cloud · Ns"
#   "  Backup:    YYYY-MM-DD HH:MM · ✓ SIZE · local only (cloud not mounted)"
#   "  Backup:    YYYY-MM-DD HH:MM · FAILED ⚠"
#   "  Backup:    no run today"
#
#   "  Recovery:  YYYY-MM-DD HH:MM · ✓ snapshot saved"
#   "  Recovery:  skipped (cloud not mounted)"
#   "  Recovery:  YYYY-MM-DD HH:MM · FAILED ⚠"
#   "  Recovery:  no run today"
#
# Log formats:
#   server-backup-cron.log:
#     [2026-03-27 04:03:37] [INFO] [pid=N] Backup created successfully: /path/file (15G)
#     [2026-03-27 04:03:37] [INFO] [pid=N] Cloud copy: /path/...
#     [2026-03-27 04:03:37] [WARN] [pid=N] Cloud backup skipped — /mnt/cloud was not mounted...
#     [2026-03-27 04:03:37] [INFO] [pid=N] Duration: 215s
#     [2026-03-27 04:00:01] [ERROR] [pid=N] Backup failed at line N...
#
#   recovery-snapshot.log:
#     [2026-03-27T04:30:01+02:00] [INFO] Recovery snapshot complete
#     [2026-03-27T04:30:01+02:00] [ERROR] /mnt/cloud is not mounted — skipping snapshot
#
# Test:    sudo bash checks/backup.sh
# Always exits 0 — never aborts the report.

set -euo pipefail

BACKUP_LOG="/var/log/server-backup-cron.log"
RECOVERY_LOG="/var/log/recovery-snapshot.log"
TODAY=$(date +%Y-%m-%d)

# ── server-backup.sh ──────────────────────────────────────────────────────────

if [[ ! -f "$BACKUP_LOG" ]]; then
  printf "  %-9s  %s\n" "Backup:" "no log found"
else
  # Extract lines from today's date in the log
  TODAY_LINES=$(grep "^\[$TODAY" "$BACKUP_LOG" 2>/dev/null || true)

  if [[ -z "$TODAY_LINES" ]]; then
    printf "  %-9s  %s\n" "Backup:" "no run today"
  elif echo "$TODAY_LINES" | grep -q "\[ERROR\]"; then
    FAIL_TIME=$(echo "$TODAY_LINES" | grep "\[ERROR\]" | tail -1 | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}' | head -1)
    printf "  %-9s  %s %s\n" "Backup:" "${FAIL_TIME} · FAILED (check ${BACKUP_LOG})" "⚠"
  elif echo "$TODAY_LINES" | grep -q "Backup created successfully"; then
    SUCCESS_LINE=$(echo "$TODAY_LINES" | grep "Backup created successfully" | tail -1)
    BACKUP_TIME=$(echo "$SUCCESS_LINE" | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}' | head -1)
    BACKUP_SIZE=$(echo "$SUCCESS_LINE" | grep -oP '\(\K[^)]+(?=\))' | tail -1)

    DURATION_LINE=$(echo "$TODAY_LINES" | grep "Duration:" | tail -1)
    DURATION=$(echo "$DURATION_LINE" | grep -oP 'Duration: \K\d+s' | head -1)
    DURATION=${DURATION:-"?s"}

    if echo "$TODAY_LINES" | grep -q "Cloud copy:"; then
      STORE="local+cloud"
    elif echo "$TODAY_LINES" | grep -q "Cloud backup skipped"; then
      STORE="local only (cloud not mounted)"
    else
      STORE="local"
    fi

    printf "  %-9s  %s\n" "Backup:" "${BACKUP_TIME} · ✓ ${BACKUP_SIZE} · ${STORE} · ${DURATION}"
  else
    # Today's lines exist but no success or error yet.
    # Check if the backup is currently running (lock file held).
    if flock -n /var/lock/server-backup.lock true 2>/dev/null; then
      # Lock is free → backup started but finished without a clear result line
      START_TIME=$(echo "$TODAY_LINES" | grep "Starting backup:" | tail -1 | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}' | head -1)
      printf "  %-9s  %s %s\n" "Backup:" "${START_TIME:-today} · started but result unclear (check ${BACKUP_LOG})" "⚠"
    else
      # Lock is held → backup is currently in progress
      START_TIME=$(echo "$TODAY_LINES" | grep "Starting backup:" | tail -1 | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}' | head -1)
      printf "  %-9s  %s\n" "Backup:" "${START_TIME:-today} · in progress..."
    fi
  fi
fi

# ── recovery-snapshot.sh ──────────────────────────────────────────────────────

if [[ ! -f "$RECOVERY_LOG" ]]; then
  printf "  %-9s  %s\n" "Recovery:" "no log found"
else
  # recovery-snapshot.log uses ISO timestamps: [2026-03-27T04:30:01+02:00]
  # Extract just the date portion to match today
  TODAY_LINES=$(grep "^\[$TODAY" "$RECOVERY_LOG" 2>/dev/null || true)

  if [[ -z "$TODAY_LINES" ]]; then
    printf "  %-9s  %s\n" "Recovery:" "no run today"
  elif echo "$TODAY_LINES" | grep -q "not mounted"; then
    printf "  %-9s  %s\n" "Recovery:" "skipped (cloud not mounted)"
  elif echo "$TODAY_LINES" | grep -q "Recovery snapshot complete"; then
    SNAP_LINE=$(echo "$TODAY_LINES" | grep "Recovery snapshot complete" | tail -1)
    SNAP_TIME=$(echo "$SNAP_LINE" | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}' | head -1 | tr 'T' ' ')
    printf "  %-9s  %s\n" "Recovery:" "${SNAP_TIME} · ✓ snapshot saved"
  elif echo "$TODAY_LINES" | grep -q "\[ERROR\]"; then
    FAIL_TIME=$(echo "$TODAY_LINES" | grep "\[ERROR\]" | tail -1 | grep -oP '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}' | head -1 | tr 'T' ' ')
    printf "  %-9s  %s %s\n" "Recovery:" "${FAIL_TIME} · FAILED (check ${RECOVERY_LOG})" "⚠"
  else
    printf "  %-9s  %s\n" "Recovery:" "ran today (check log for details)"
  fi
fi
