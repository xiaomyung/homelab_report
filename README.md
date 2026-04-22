# homelab_report

Sends a daily Telegram message summarising the security posture, system health,
and backup status of a Debian-based homelab server. Fires at noon via a systemd
timer; no persistent process, no framework — just shell and curl.

An optional LLM-generated "at a glance" summary is posted as a reply to the
main message when a local Ollama endpoint is available — see [At a glance
summary](#at-a-glance-summary).

## What it reports

```
🏠 Homelab Report — 2026-04-02 12:00

🛡 Security
  AIDE:      2026-04-02 01:52 · 0 added · 0 changed · 0 removed
  ClamAV:    2026-03-29 · 160567 files · 0 infected
  rkhunter:  2026-04-02 · all clear
  SSH auth:  last 24h · 0 failure(s)
  fail2ban:  2 jail(s) · 0 banned

💾 Disk  [checked 12:00]
  /:             29% used (of 233G)
  /mnt/storage:  16% used (of 916G)
  /mnt/cloud:    28% used (of 7.3T)

🖥 System  [checked 12:00]
  Uptime:    1 week, 1 day, 7 hours, 47 minutes
  Reboot:    not required
  Memory:    RAM 8.4Gi/62Gi
  Drives:    sda OK · sdb OK · nvme0n1 OK
  Docker:    25/26 up
             stopped: minecraft/wings
  Logins:    10 in last 24h
             apollo from 192.168.0.138 at 04-02, last 18:14, (5)
             apollo from 192.168.0.138 at 04-01, last 21:13, (3)

🗄 Backups
  Backup:    2026-04-02 04:01 · ✓ 5.5G · local+cloud · 68s
  Recovery:  2026-04-02 04:35 · ✓ snapshot saved
```

Followed, when the LLM endpoint is reachable, by a threaded reply:

```
🔎 At a glance
  ✅ All clear
```

On an anomaly day (any check line ending with `⚠`), the same slot contains
3–5 bullets instead:

```
🔎 At a glance
  • AIDE: 27595 added · 433 changed · 119 removed
  • rkhunter: 8 warning(s)
```

## Requirements

- Debian/Ubuntu server
- `curl` (standard on Debian)
- A Telegram bot token from [@BotFather](https://t.me/BotFather)
- Root access (reads system logs and runs `smartctl`, `docker ps`, etc.)

Optional (checks are skipped if not installed):
- `aide`, `clamav`, `rkhunter`, `fail2ban`, `smartmontools`, `docker`
- `python3` + an Ollama endpoint serving an instruct model at
  `http://localhost:11435/api/chat` for the LLM "at a glance" summary
  (`python3` ships with Debian; see [At a glance summary](#at-a-glance-summary)
  for details and how to disable)

## Setup

**1. Clone and enter the directory**

```bash
git clone https://github.com/xiaomyung/homelab_report.git
cd homelab_report
```

**2. Create and secure the credentials file**

```bash
sudo cp .env.example .env
sudo chown root:root .env
sudo chmod 600 .env
sudo nano .env          # fill in TG_BOT_TOKEN and TG_CHAT_ID
```

To find your `TG_CHAT_ID`: send any message to your bot, then call:
```bash
curl "https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates"
# look for: "chat": {"id": 123456789}
```

**3. Make scripts executable**

```bash
sudo chmod +x report.sh checks/*.sh
```

**4. Test manually**

```bash
sudo bash report.sh
```

This sends a real message to your Telegram chat.

**5. Set up the systemd timer**

Create `/etc/systemd/system/tg-homelab-report.service`:
```ini
[Unit]
Description=Homelab Telegram daily report

[Service]
Type=oneshot
ExecStart=/bin/bash /path/to/homelab_report/report.sh
```

Create `/etc/systemd/system/tg-homelab-report.timer`:
```ini
[Unit]
Description=Run homelab Telegram report daily at noon

[Timer]
OnCalendar=*-*-* 12:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tg-homelab-report.timer
sudo systemctl list-timers | grep tg-
```

## Checks

| Script | Source | Description |
|--------|--------|-------------|
| `aide.sh` | `/var/log/aide/aide-YYYY-MM-DD.log` | File integrity changes |
| `clamav.sh` | `/var/log/clamav/weekly-scan.log` | Antivirus scan result |
| `rkhunter.sh` | `/var/log/rkhunter.log` | Rootkit scan warnings |
| `auth.sh` | `/var/log/auth.log` | SSH auth failures in last 24h |
| `fail2ban.sh` | `fail2ban-client` | Jail count and currently banned IPs |
| `disk.sh` | `df -h` | Usage for /, /mnt/storage, /mnt/cloud |
| `system.sh` | `uptime`, `apt`, `/var/run/reboot-required` | Uptime, reboot flag, security updates |
| `memory.sh` | `free -h` | RAM and swap usage |
| `smart.sh` | `smartctl -H` | Drive health for sda, sdb, nvme0n1 |
| `docker.sh` | `docker ps -a` | Up/total count, stopped and crashed containers by name |
| `logins.sh` | `last` | Successful logins in last 24h, grouped by user+IP+date with count |
| `systemd.sh` | `systemctl --failed` | Failed systemd units (omitted if none) |
| `backup.sh` | `/var/log/server-backup-cron.log`, `/var/log/recovery-snapshot.log` | Backup and recovery snapshot results |

Each check script is independent — a failure in one never blocks the others or
prevents the report from sending.

## At a glance summary

After the main message is accepted, `report.sh` pipes the HTML-stripped
message through `checks/at-a-glance.sh`, which posts a summary back to
Telegram as a threaded reply.

The logic is deliberately thin: the script looks for lines in the main report
that end with the `⚠` character — those are the anomalies the individual
check scripts have already flagged — and asks the LLM to turn them into
short bullets. On a report with no `⚠` markers, the summary is literally
`✅ All clear`. The LLM never decides what is or isn't an anomaly; the check
scripts do. This keeps output grounded in the existing convention and
minimises hallucination surface.

**Dependencies:**

- An Ollama-compatible endpoint at `http://localhost:11435/api/chat`
  serving an instruct-capable model. The script is tagged for
  `qwen3-coder:30b` in `MODEL=` near the top of `checks/at-a-glance.sh` —
  swap it for any instruct model you prefer.
- `python3` (stdlib `json` only; no `jq` or other package needed).

**Failure behaviour:** if Ollama is unreachable, the model is missing, or
the call exceeds the `MAX_TIME` cap (default 240s), the reply is a single
line `⚠️ Summary unavailable (<reason>)`. The AIDE attachment and the main
report are never blocked by a summary failure.

**Performance note:** on CPU inference the 30B MoE takes ~2–3 minutes per
call (prefill dominates). Use a smaller or GPU-backed model if you need
faster turnaround; the prompt is generic enough to work with most
instruct-tuned models.

**Disabling:** delete `checks/at-a-glance.sh`. `report.sh` gracefully skips
the summary when the script is missing.

## AIDE diff attachment

When AIDE detects unexpected filesystem changes, `report.sh` sends a trimmed
diff as a file attachment — as a reply to the main report message. Known
daily changes (`audit.log`, `wtmp.db`) are filtered out automatically; the
attachment only appears when something genuinely unexpected has changed.

## Adding a new check

1. Create `checks/newcheck.sh`:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   # Always exit 0 — never abort the report
   echo "  Label:    result"
   ```

2. `chmod +x checks/newcheck.sh`

3. In `report.sh`, add `NEWCHECK=$(run_check newcheck.sh)` and include
   `${NEWCHECK}` in the relevant `MSG` section.

## Debugging

```bash
# Run a single check
sudo bash checks/aide.sh

# Check the last timer run
journalctl -u tg-homelab-report.service -n 50

# Test Telegram connectivity
source .env
curl -s "https://api.telegram.org/bot${TG_BOT_TOKEN}/getMe"
```
