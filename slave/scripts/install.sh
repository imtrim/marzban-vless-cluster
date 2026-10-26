#!/bin/sh
# Install node2: firewall (+ boot unit), marzban-node + Caddy cover site.
set -eu
DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$DIR"
command -v docker >/dev/null || { echo "install docker first: curl -fsSL https://get.docker.com | sh" >&2; exit 1; }
[ -f .env ] || cp .env.example .env
. ./.env

mkdir -p /var/lib/marzban-node
if [ ! -s /var/lib/marzban-node/ssl_client_cert.pem ]; then
  echo "missing /var/lib/marzban-node/ssl_client_cert.pem" >&2
  echo "panel -> Nodes -> Add node -> copy certificate, then: make slave-cert" >&2
  exit 1
fi

"$DIR/scripts/firewall.sh"

cat > /etc/systemd/system/node2-firewall.service <<UNIT
[Unit]
Description=node2 firewall (Marzban node ports, 443 redirect)
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$DIR/scripts/firewall.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable node2-firewall.service

docker compose -f compose.yml --env-file .env up -d
docker compose -f compose.yml ps
