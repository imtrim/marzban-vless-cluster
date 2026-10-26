#!/bin/sh
# One-shot: secrets, optional pre-install hook, Marzban.
# Requires a Caddy (or other TLS site) on 127.0.0.1:8443 as REALITY dest; :443 must be free.

. "$(dirname -- "$0")/lib.sh"

require_cmd docker
require_cmd openssl

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose plugin is required" >&2
  exit 1
fi

"$ROOT/scripts/setup-secrets.sh"
if [ -n "${MASTER_PRE_INSTALL:-}" ]; then
  echo "running pre-install hook: $MASTER_PRE_INSTALL"
  "$MASTER_PRE_INSTALL"
fi

echo "waiting for a site on 127.0.0.1:8443 (and :443 to be free)"
i=0
while [ "$i" -lt 45 ]; do
  if ss -lnt 2>/dev/null | grep -q ':8443'; then
    if ! ss -lntp 2>/dev/null | grep ':443' | grep -q caddy; then
      break
    fi
  fi
  i=$((i + 1))
  sleep 1
done

if ss -lntp 2>/dev/null | grep ':443' | grep -q caddy; then
  echo "Caddy is still bound to :443 — move it to 127.0.0.1:8443 first" >&2
  exit 1
fi

"$ROOT/scripts/start.sh"
echo
echo "waiting for Marzban panel"
# shellcheck disable=SC1090
. "$ENV_FILE"
port="${UVICORN_PORT:-2053}"
i=0
while [ "$i" -lt 60 ]; do
  if curl -skf -o /dev/null --connect-timeout 2 "https://127.0.0.1:${port}/dashboard/" \
    || curl -sf -o /dev/null --connect-timeout 2 "http://127.0.0.1:${port}/dashboard/"; then
    break
  fi
  i=$((i + 1))
  sleep 2
done

"$ROOT/scripts/configure-hosts.sh" || true

echo "install finished"
echo "panel: ssh -L ${port}:127.0.0.1:${port} root@${MASTER_IP}, then https://localhost:${port}/dashboard/"
echo "login: see SUDO_USERNAME / SUDO_PASSWORD in $ENV_FILE"
