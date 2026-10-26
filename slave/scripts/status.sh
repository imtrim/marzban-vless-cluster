#!/bin/sh
set -u
DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$DIR"; [ -f .env ] && . ./.env
D="${COVER_DOMAIN:?set COVER_DOMAIN in slave/.env}"
docker compose -f compose.yml ps
ss -lntp | grep -E ':(80|443|8443|8444|62050|62051) ' || true
curl -sS -o /dev/null -w "cover via caddy %{http_code}\n" --resolve "$D:8443:127.0.0.1" "https://$D:8443/" || true
iptables -t nat -S PREROUTING | grep REDIRECT || true
