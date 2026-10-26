#!/bin/sh
# The node2 inbound (:8444) also runs on this server's core (Marzban runs all
# inbounds everywhere). Drop external access to it here; loopback still works.
# Idempotent. Called from start.sh.
set -eu
PORT="${NODE2_INBOUND_PORT:-8444}"
for ipt in iptables ip6tables; do
  command -v "$ipt" >/dev/null 2>&1 || continue
  if ! "$ipt" -C INPUT ! -i lo -p tcp --dport "$PORT" -j DROP 2>/dev/null; then
    "$ipt" -I INPUT ! -i lo -p tcp --dport "$PORT" -j DROP
    echo "$ipt: dropping external tcp/$PORT"
  fi
done
