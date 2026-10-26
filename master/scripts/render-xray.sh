#!/bin/sh
# Render xray_config.json into the Marzban data dir from the example + .env keys.
# Existing inbound clients are kept (per tag) so Marzban users survive a re-render.
#
# Inbounds:
#   "VLESS TCP REALITY"       :443  — master (MASTER_DOMAIN + MASTER_EXTRA_DOMAINS self-steal)
#   "VLESS TCP REALITY NODE2" :8444 — slave (SLAVE_DOMAIN). Marzban runs every
#     inbound on the panel core AND on every node, so it cannot share :443.
#     On node2, node/scripts/firewall.sh redirects public :443 -> :8444;
#     on this server scripts/block-node2-port.sh drops external :8444.

. "$(dirname -- "$0")/lib.sh"

require_cmd python3

# shellcheck disable=SC1090
. "$ENV_FILE"

data_dir="${MARZBAN_DATA:-/var/lib/marzban}"
mkdir -p "$data_dir"
out="$data_dir/xray_config.json"

if [ -z "${MASTER_DOMAIN:-}" ] || [ -z "${SLAVE_DOMAIN:-}" ]; then
  echo "MASTER_DOMAIN / SLAVE_DOMAIN missing in $ENV_FILE" >&2
  exit 1
fi

if [ -z "${REALITY_PRIVATE_KEY:-}" ] || [ -z "${REALITY_SHORT_ID:-}" ]; then
  echo "REALITY keys missing in $ENV_FILE" >&2
  exit 1
fi

python3 - "$ROOT/docker/xray_config.example.json" "$out" \
  "$REALITY_PRIVATE_KEY" "$REALITY_SHORT_ID" \
  "${NODE2_REALITY_PRIVATE_KEY:-}" "${NODE2_REALITY_SHORT_ID:-}" \
  "$MASTER_DOMAIN ${MASTER_EXTRA_DOMAINS:-}" "$SLAVE_DOMAIN" <<'PY'
import json, os, sys

src, dest, priv, short, n2priv, n2short, mnames, snames = sys.argv[1:9]
with open(src, encoding="utf-8") as fh:
    cfg = json.load(fh)

names = {
    "VLESS TCP REALITY": mnames.split(),
    "VLESS TCP REALITY NODE2": snames.split(),
}
keys = {
    "VLESS TCP REALITY": (priv, short),
    "VLESS TCP REALITY NODE2": (n2priv, n2short),
}

existing_clients = {}
if os.path.exists(dest):
    with open(dest, encoding="utf-8") as fh:
        existing = json.load(fh)
    for inbound in existing.get("inbounds", []):
        clients = inbound.get("settings", {}).get("clients")
        if clients:
            existing_clients[inbound.get("tag")] = clients

inbounds = []
for inbound in cfg["inbounds"]:
    tag = inbound.get("tag")
    k_priv, k_short = keys.get(tag, ("", ""))
    if not k_priv or not k_short:
        print("skip inbound (no keys in .env):", tag)
        continue
    if tag in existing_clients:
        inbound.setdefault("settings", {})["clients"] = existing_clients[tag]
    settings = inbound["streamSettings"]["realitySettings"]
    settings["privateKey"] = k_priv
    settings["shortIds"] = [k_short]
    settings["serverNames"] = names[tag]
    inbounds.append(inbound)
cfg["inbounds"] = inbounds

with open(dest, "w", encoding="utf-8") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
print("wrote", dest)
PY
chmod 644 "$out"
