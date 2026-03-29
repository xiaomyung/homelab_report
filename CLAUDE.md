# /srv/services/tg — Telegram services

Services that send Telegram notifications for the homelab.

## Projects

- `homelab_report/` — Daily noon security/health/backup report via Bot API curl.
  See `homelab_report/CLAUDE.md` for full documentation.

## Conventions

- All credentials in `.env` files (root:root, mode 600)
- No persistent bot processes — all sends via one-shot curl to Bot API
- No modifications to package-managed scripts in /etc/
- Root commands for the user go to /tmp as shell scripts
