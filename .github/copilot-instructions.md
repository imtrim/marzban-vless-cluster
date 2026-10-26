# Copilot instructions

Follow [AGENTS.md](../AGENTS.md). Key points:

- POSIX `sh`, idempotent scripts; `master/scripts/*` source `lib.sh`.
- Never commit `.env`, keys, certificates or real IPs/domains; use `<ip_master>`, `<ip_slave>`, `<master_domain>`, `<slave_domain>`.
- Images stay pinned by tag and digest.
- Human docs (README.md, CONTRIBUTING.md, docs/) are in Russian; write doc changes in Russian.
- Host-specific scripts go to gitignored `local/` and `local.mk`.
