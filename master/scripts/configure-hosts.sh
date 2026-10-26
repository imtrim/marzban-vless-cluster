#!/bin/sh
# Point Marzban subscription hosts at the cover SNI (MASTER_DOMAIN).

. "$(dirname -- "$0")/lib.sh"

require_cmd curl
require_cmd python3

# shellcheck disable=SC1090
. "$ENV_FILE"

port="${UVICORN_PORT:-2053}"
if curl -skf -o /dev/null --connect-timeout 2 "https://127.0.0.1:${port}/dashboard/"; then
  base="https://127.0.0.1:${port}"
  curl_insecure=-k
else
  base="http://127.0.0.1:${port}"
  curl_insecure=
fi

token="$(
  curl -sS $curl_insecure -X POST "$base/api/admin/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "username=${SUDO_USERNAME}" \
    --data-urlencode "password=${SUDO_PASSWORD}"
)"
access="$(printf '%s' "$token" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')"
if [ -z "$access" ]; then
  echo "failed to obtain admin token:" >&2
  echo "$token" >&2
  exit 1
fi

payload='{"VLESS TCP REALITY":[{"remark":"master ({USERNAME})","address":"{SERVER_IP}","port":null,"sni":"'"$MASTER_DOMAIN"'","host":"","path":"","security":"inbound_default","alpn":"","fingerprint":"chrome","allowinsecure":false,"is_disabled":false,"mux_enable":false,"fragment_setting":null,"noise_setting":null,"random_user_agent":false,"use_sni_as_host":false}]}'

code="$(curl -sS $curl_insecure -o /tmp/marzban-hosts.json -w '%{http_code}' -X PUT "$base/api/hosts" \
  -H "Authorization: Bearer $access" -H 'Content-Type: application/json' -d "$payload")"
if [ "$code" != "200" ]; then
  echo "configure hosts failed ($code):" >&2
  cat /tmp/marzban-hosts.json >&2
  echo >&2
  exit 1
fi
echo "hosts SNI set to $MASTER_DOMAIN"
