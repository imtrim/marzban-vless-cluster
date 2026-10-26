#!/bin/sh
# node2 firewall (idempotent):
#  - 62050/62051 (Marzban node API / Xray API) only from PANEL_IP
#  - public tcp/PUBLIC_PORT (443) -> INBOUND_PORT (8444, NODE2 inbound)
# Uses iptables (works with iptables-nft); does not touch other rules.
set -eu
DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
[ -f "$DIR/.env" ] && . "$DIR/.env"
PANEL_IP="${PANEL_IP:?set PANEL_IP in slave/.env}"
SERVICE_PORT="${SERVICE_PORT:-62050}"
XRAY_API_PORT="${XRAY_API_PORT:-62051}"
PUBLIC_PORT="${PUBLIC_PORT:-443}"
INBOUND_PORT="${INBOUND_PORT:-8444}"
# clean IP clients connect to (empty = any local address)
PUBLIC_IP="${PUBLIC_IP:-}"

add() { # add <cmd> <table> <chain> rule...
  cmd=$1 table=$2 chain=$3; shift 3
  "$cmd" -t "$table" -C "$chain" "$@" 2>/dev/null || "$cmd" -t "$table" -I "$chain" "$@"
}

for p in "$SERVICE_PORT" "$XRAY_API_PORT"; do
  # insert DROP first, then ACCEPT (inserted above it)
  add iptables filter INPUT -p tcp --dport "$p" -j DROP
  add iptables filter INPUT -p tcp --dport "$p" -i lo -j ACCEPT
  add iptables filter INPUT -p tcp --dport "$p" -s "$PANEL_IP" -j ACCEPT
  if command -v ip6tables >/dev/null 2>&1; then
    add ip6tables filter INPUT -p tcp --dport "$p" -j DROP
    add ip6tables filter INPUT -p tcp --dport "$p" -i lo -j ACCEPT
  fi
done

if [ -n "$PUBLIC_IP" ]; then
  add iptables nat PREROUTING -d "$PUBLIC_IP" -p tcp --dport "$PUBLIC_PORT" -j REDIRECT --to-ports "$INBOUND_PORT"
  # main-server inbound also binds :443 here; keep it off the other IPs
  add iptables filter INPUT ! -i lo ! -d "$PUBLIC_IP" -p tcp --dport "$PUBLIC_PORT" -j DROP
else
  add iptables nat PREROUTING -p tcp --dport "$PUBLIC_PORT" -j REDIRECT --to-ports "$INBOUND_PORT"
fi
# INBOUND_PORT only via the redirect
add iptables filter INPUT ! -i lo -p tcp --dport "$INBOUND_PORT" -m conntrack ! --ctstate DNAT -j DROP
if command -v ip6tables >/dev/null 2>&1; then
  add ip6tables filter INPUT ! -i lo -p tcp --dport "$PUBLIC_PORT" -j DROP
  add ip6tables filter INPUT ! -i lo -p tcp --dport "$INBOUND_PORT" -j DROP
fi

echo "firewall: $SERVICE_PORT,$XRAY_API_PORT only from $PANEL_IP; ${PUBLIC_IP:-*}:$PUBLIC_PORT -> $INBOUND_PORT"
iptables -S INPUT | grep -E "$SERVICE_PORT|$XRAY_API_PORT" || true
iptables -t nat -S PREROUTING | grep -- "--dport $PUBLIC_PORT" || true
