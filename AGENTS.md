# AGENTS.md

Guidance for AI coding agents working on **marzban-vless-cluster**: Marzban panel + VLESS TCP REALITY on several servers (one `master` with the panel, N `slave` nodes running marzban-node).

## Layout
```
Makefile                 entry point: master-* targets (panel server), slave-* targets (node)
master/.env.example      panel + cluster variables (real values only in master/.env, gitignored)
master/docker/           compose.yml (gozargah/marzban, pinned digest), xray_config.example.json
master/scripts/          install, start/stop, render-xray, setup-secrets, configure-hosts, probe-user, block-node2-port, status, logs; lib.sh is sourced
master/site/             static cover site for <master_domain>
slave/.env.example       node variables (real values only in slave/.env)
slave/compose.yml        marzban-node + node2-caddy (pinned digests); slave/Caddyfile; slave/site/
slave/scripts/           firewall.sh (iptables, idempotent), install.sh, status.sh
docs/                    user docs, Russian only (README.md, CONTRIBUTING.md are Russian too)
SECURITY.md              private vulnerability reporting policy (Russian)
CHANGELOG.md             Keep a Changelog (Russian); update [Unreleased] with every change
CODE_OF_CONDUCT.md       Contributor Covenant 2.1 (Russian)
.editorconfig            formatting: LF, utf-8, 2 spaces; tabs in Makefile and Caddyfile
local/, local.mk         gitignored host-specific hooks (never add them to git)
```

## Commands
- `make help` lists targets.
- Master: `make master-install | master-start | master-stop | master-restart | master-status | master-logs | master-secrets | master-hosts | master-probe`.
- Slave: `make slave-cert | slave-firewall | slave-install | slave-up | slave-down | slave-status | slave-logs`.
- Lint shell scripts: `sh -n <file>`; `shellcheck` if available. There are no automated tests; verification is described in `docs/verification.md`.

## Conventions
- POSIX `sh`, `set -eu`, idempotent scripts; scripts in `master/scripts` source `lib.sh`.
- Firewall scripts add rules with `-C || -I`; never flush or rewrite foreign rules.
- Docker images are pinned by tag **and** digest; marzban v0.8.4 with marzban-node v0.5.2.
- Each node inbound needs its own port (NODE2 = 8444); see `docs/architecture.md`.
- Human docs (README.md, CONTRIBUTING.md, docs/) are written in **Russian**; AI-assistant files stay in English. Describe only commands that exist in the repo. Keep docs/warnings.md in sync with risky changes.

## Safety rules
- Never commit `.env`, keys, certificates, `*.sqlite3`, or anything from `/var/lib/marzban*`.
- Never write real IP addresses, domains or home-directory paths. Use `<ip_master>`, `<ip_slave>`, `<master_domain>`, `<slave_domain>`.
- Keep host-specific glue in `local/` + `local.mk`, not in tracked files.
- Restarting `marzban` drops live client connections; do not restart it without need.
- Never expose the panel port (2053) publicly; access is via SSH tunnel only.
- Update CHANGELOG.md ([Unreleased]) with every user-visible change.
- Do not force-push.
- Never describe a vulnerability in public issues/PRs; follow SECURITY.md.
- The only intentionally public contact is github@imtrim.dev.
