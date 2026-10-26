#!/bin/sh
# Create, list, and disable a Marzban user to prove the panel API works.

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
user="${1:-probe}"

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

auth="Authorization: Bearer $access"

exists="$(curl -sS $curl_insecure -o /tmp/marzban-user.json -w '%{http_code}' -H "$auth" "$base/api/user/$user" || true)"
if [ "$exists" = "200" ]; then
  echo "keep existing user $user"
else
  payload="$(python3 -c 'import json,sys; print(json.dumps({
    "username": sys.argv[1],
    "proxies": {"vless": {"flow": "xtls-rprx-vision"}},
    "inbounds": {"vless": ["VLESS TCP REALITY"]},
    "status": "active",
    "data_limit": 0,
    "expire": 0,
  }))' "$user")"
  code="$(curl -sS $curl_insecure -o /tmp/marzban-user.json -w '%{http_code}' -X POST "$base/api/user" \
    -H "$auth" -H 'Content-Type: application/json' -d "$payload")"
  if [ "$code" != "200" ]; then
    echo "create user failed ($code):" >&2
    cat /tmp/marzban-user.json >&2
    echo >&2
    exit 1
  fi
  echo "created user $user"
fi

python3 - <<'PY'
import json
with open("/tmp/marzban-user.json", encoding="utf-8") as fh:
    data = json.load(fh)
print("status", data.get("status"))
links = data.get("links") or []
if links:
    print("link", links[0])
elif data.get("subscription_url"):
    print("subscription", data["subscription_url"])
PY

disable="$(python3 -c 'import json; print(json.dumps({"status":"disabled"}))')"
code="$(curl -sS $curl_insecure -o /tmp/marzban-user.json -w '%{http_code}' -X PUT "$base/api/user/$user" \
  -H "$auth" -H 'Content-Type: application/json' -d "$disable")"
if [ "$code" != "200" ]; then
  echo "disable user failed ($code):" >&2
  cat /tmp/marzban-user.json >&2
  echo >&2
  exit 1
fi

python3 - <<'PY'
import json
with open("/tmp/marzban-user.json", encoding="utf-8") as fh:
    data = json.load(fh)
print("disabled", data.get("username"), data.get("status"))
PY

enable="$(python3 -c 'import json; print(json.dumps({"status":"active"}))')"
code="$(curl -sS $curl_insecure -o /tmp/marzban-user.json -w '%{http_code}' -X PUT "$base/api/user/$user" \
  -H "$auth" -H 'Content-Type: application/json' -d "$enable")"
if [ "$code" != "200" ]; then
  echo "re-enable user failed ($code):" >&2
  cat /tmp/marzban-user.json >&2
  echo >&2
  exit 1
fi

python3 - <<'PY'
import json
with open("/tmp/marzban-user.json", encoding="utf-8") as fh:
    data = json.load(fh)
print("enabled", data.get("username"), data.get("status"))
links = data.get("links") or []
if links:
    print("link", links[0])
PY
