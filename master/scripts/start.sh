#!/bin/sh

. "$(dirname -- "$0")/lib.sh"

require_cmd docker
if [ ! -f "$ENV_FILE" ]; then
  echo "missing $ENV_FILE — run scripts/install.sh first" >&2
  exit 1
fi
"$ROOT/scripts/render-xray.sh"
"$ROOT/scripts/block-node2-port.sh" || echo "warning: could not block node2 port" >&2
compose up -d
compose ps
