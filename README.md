# tg — Homelab Telegram Bots

A collection of Telegram bots for a self-hosted homelab — notifications,
automations, and utilities. Each bot lives in its own subdirectory with its own
credentials and deployment setup.

## Bots

| Bot | Description |
|-----|-------------|
| [`homelab_report/`](homelab_report/) | Daily security, health, and backup status report |

## Conventions

- **One directory per bot** — each bot is self-contained with its own `.env`, scripts, and README
- **Credentials never in code** — all secrets in `.env` files (root:root, mode 600), never committed; copy `.env.example` to get started
- **No shared dependencies** — bots don't depend on each other; each can be deployed or removed independently

## Repository structure

```
tg/
├── homelab_report/     ← daily security + health + backup report
│   ├── README.md
│   ├── .env.example    ← credential template
│   ├── report.sh
│   └── checks/
└── .gitignore
```
