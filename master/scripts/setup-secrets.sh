#!/bin/sh
# Create .env and Reality keys if missing. Existing files are kept.

. "$(dirname -- "$0")/lib.sh"

require_cmd openssl
require_cmd docker

data_dir="${MARZBAN_DATA:-/var/lib/marzban}"
cert_dir="$data_dir/certs"
mkdir -p "$cert_dir"
if [ ! -f "$cert_dir/panel.crt" ] || [ ! -f "$cert_dir/panel.key" ]; then
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$cert_dir/panel.key" -out "$cert_dir/panel.crt" \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
  chmod 600 "$cert_dir/panel.key"
  chmod 644 "$cert_dir/panel.crt"
  echo "wrote self-signed panel certs in $cert_dir"
fi

if [ ! -f "$ENV_FILE" ]; then
  password="$(openssl rand -hex 16)"
  cat > "$ENV_FILE" <<EOF
UVICORN_HOST=127.0.0.1
UVICORN_PORT=2053
UVICORN_SSL_CERTFILE=/var/lib/marzban/certs/panel.crt
UVICORN_SSL_KEYFILE=/var/lib/marzban/certs/panel.key
UVICORN_SSL_CA_TYPE=private
SUDO_USERNAME=admin
SUDO_PASSWORD=$password
SQLALCHEMY_DATABASE_URL=sqlite:////var/lib/marzban/db.sqlite3
XRAY_JSON=/var/lib/marzban/xray_config.json
XRAY_SUBSCRIPTION_URL_PREFIX=https://${MASTER_DOMAIN:-<master_domain>}
MASTER_IP=${MASTER_IP:-<ip_master>}
MASTER_DOMAIN=${MASTER_DOMAIN:-<master_domain>}
MASTER_EXTRA_DOMAINS=
SLAVE_IP=${SLAVE_IP:-<ip_slave>}
SLAVE_DOMAIN=${SLAVE_DOMAIN:-<slave_domain>}
MARZBAN_DATA=/var/lib/marzban
REALITY_PRIVATE_KEY=
REALITY_PUBLIC_KEY=
REALITY_SHORT_ID=
EOF
  chmod 600 "$ENV_FILE"
  echo "wrote $ENV_FILE"
else
  echo "keep $ENV_FILE"
  if ! grep -q '^UVICORN_SSL_CERTFILE=' "$ENV_FILE"; then
    tmp="$(mktemp)"
    awk '
      BEGIN { FS=OFS="=" }
      $1=="UVICORN_PORT" {
        print
        print "UVICORN_SSL_CERTFILE=/var/lib/marzban/certs/panel.crt"
        print "UVICORN_SSL_KEYFILE=/var/lib/marzban/certs/panel.key"
        print "UVICORN_SSL_CA_TYPE=private"
        next
      }
      $1=="XRAY_SUBSCRIPTION_URL_PREFIX" {
        $2="https://" ENVIRON["MASTER_DOMAIN"]
      }
      { print }
    ' "$ENV_FILE" > "$tmp"
    mv "$tmp" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    echo "added panel TLS settings to $ENV_FILE"
  fi
fi

if ! grep -q '^REALITY_PRIVATE_KEY=.\+' "$ENV_FILE"; then
  keys="$(docker run --rm --entrypoint /usr/local/bin/xray ghcr.io/xtls/xray-core:latest x25519)"
  priv="$(printf '%s\n' "$keys" | awk -F': ' '/Private/{print $2; exit}')"
  pub="$(printf '%s\n' "$keys" | awk -F': ' '/Password/{print $2; exit}')"
  if [ -z "$pub" ]; then
    pub="$(printf '%s\n' "$keys" | awk -F': ' '/Public/{print $2; exit}')"
  fi
  short="$(openssl rand -hex 8)"
  if [ -z "$priv" ] || [ -z "$pub" ]; then
    echo "failed to generate Reality keys:" >&2
    echo "$keys" >&2
    exit 1
  fi
  tmp="$(mktemp)"
  awk -v priv="$priv" -v pub="$pub" -v short="$short" '
    BEGIN { FS=OFS="=" }
    $1=="REALITY_PRIVATE_KEY" { $2=priv; print; next }
    $1=="REALITY_PUBLIC_KEY" { $2=pub; print; next }
    $1=="REALITY_SHORT_ID" { $2=short; print; next }
    { print }
  ' "$ENV_FILE" > "$tmp"
  mv "$tmp" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "wrote Reality keys into $ENV_FILE"
fi
