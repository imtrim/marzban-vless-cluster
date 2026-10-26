#!/bin/sh

. "$(dirname -- "$0")/lib.sh"

require_cmd docker
compose ps
echo
# shellcheck disable=SC1090
. "$ENV_FILE"
port="${UVICORN_PORT:-2053}"
curl -skS -o /dev/null -w "panel %{http_code}\n" --connect-timeout 5 "https://127.0.0.1:${port}/dashboard/" \
  || curl -sS -o /dev/null -w "panel %{http_code}\n" --connect-timeout 5 "http://127.0.0.1:${port}/dashboard/" \
  || true
for d in $MASTER_DOMAIN ${MASTER_EXTRA_DOMAINS:-}; do
  curl -sS -o /dev/null -w "caddy-$d %{http_code}
" --resolve "$d:8443:127.0.0.1" "https://$d:8443/" || true
  curl -sS -o /dev/null -w "public-$d %{http_code}
" --resolve "$d:443:127.0.0.1" "https://$d/" || true
done
echo "panel: ssh -L ${port}:127.0.0.1:${port} root@${MASTER_IP}, then https://localhost:${port}/dashboard/"
if [ -n "${REALITY_PUBLIC_KEY:-}" ]; then
  echo "Reality publicKey: $REALITY_PUBLIC_KEY"
  echo "Reality shortId: $REALITY_SHORT_ID"
  echo "Reality SNI: $MASTER_DOMAIN"
  echo "Reality address: $MASTER_IP:443"
fi
