# /srv/services/tg — Telegram bots

Telegram bots for the homelab.

## Projects

- `homelab_report/` — Daily noon security/health/backup report via Bot API curl.
  See `homelab_report/CLAUDE.md` for full documentation.

## Git / GitHub

- Remote: https://github.com/xiaomyung/tg (public, CV-linked)
- Branch: master
- Workflow: new branch per change → commit → push; never commit directly to master
- Each bot subdirectory needs its own README.md

## Conventions

- All credentials in `.env` files (root:root, mode 600)
- No persistent bot processes — all sends via one-shot curl to Bot API
- No modifications to package-managed scripts in /etc/
- Root commands for the user go to /tmp as shell scripts
