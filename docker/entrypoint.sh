#!/bin/sh
set -eu

umask 077

fail() {
  echo "grok2api Railway entrypoint: $*" >&2
  exit 1
}

require_value() {
  name="$1"
  value="$2"
  [ -n "$value" ] || fail "missing required environment variable: $name"
}

yaml_quote() {
  value="$1"
  case "$value" in
    *'
'*) fail "environment values must not contain newlines" ;;
  esac
  escaped=$(printf '%s' "$value" | sed "s/'/''/g")
  printf "'%s'" "$escaped"
}

port="${PORT:-8000}"
case "$port" in
  ''|*[!0-9]*) fail "PORT must be an integer between 1 and 65535" ;;
esac
[ "$port" -ge 1 ] && [ "$port" -le 65535 ] || fail "PORT must be between 1 and 65535"

config_source="${GROK2API_CONFIG_SOURCE:-/run/grok2api/config.yaml}"

# A mounted config remains supported for advanced deployments. Railway uses
# generated configuration so secrets never need to be committed to Git.
if [ ! -f "$config_source" ]; then
  jwt_secret="${GROK2API_JWT_SECRET:-}"
  encryption_key="${GROK2API_CREDENTIAL_ENCRYPTION_KEY:-}"
  admin_username="${GROK2API_ADMIN_USERNAME:-admin}"
  admin_password="${GROK2API_ADMIN_PASSWORD:-}"

  require_value GROK2API_JWT_SECRET "$jwt_secret"
  require_value GROK2API_CREDENTIAL_ENCRYPTION_KEY "$encryption_key"
  require_value GROK2API_ADMIN_USERNAME "$admin_username"
  require_value GROK2API_ADMIN_PASSWORD "$admin_password"

  public_api_base_url="${GROK2API_PUBLIC_API_BASE_URL:-}"
  if [ -z "$public_api_base_url" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    public_api_base_url="https://${RAILWAY_PUBLIC_DOMAIN}"
  fi
  if [ -z "$public_api_base_url" ]; then
    public_api_base_url="http://127.0.0.1:${port}"
  fi
  public_api_base_url="${public_api_base_url%/}"

  secure_cookies="${GROK2API_SECURE_COOKIES:-}"
  if [ -z "$secure_cookies" ]; then
    case "$public_api_base_url" in
      https://*) secure_cookies=true ;;
      *) secure_cookies=false ;;
    esac
  fi
  case "$secure_cookies" in
    true|false) ;;
    *) fail "GROK2API_SECURE_COOKIES must be true or false" ;;
  esac

  config_source=/run/grok2api/config.yaml
  mkdir -p /run/grok2api
  config_tmp="${config_source}.tmp"
  {
    printf 'auth:\n'
    printf '  secureCookies: %s\n' "$secure_cookies"
    printf 'secrets:\n'
    printf '  jwtSecret: %s\n' "$(yaml_quote "$jwt_secret")"
    printf '  credentialEncryptionKey: %s\n' "$(yaml_quote "$encryption_key")"
    printf 'bootstrapAdmin:\n'
    printf '  username: %s\n' "$(yaml_quote "$admin_username")"
    printf '  password: %s\n' "$(yaml_quote "$admin_password")"
    printf 'frontend:\n'
    printf '  publicApiBaseURL: %s\n' "$(yaml_quote "$public_api_base_url")"
    printf '  staticPath: %s\n' "$(yaml_quote '/app/frontend/dist')"
    printf 'database:\n'
    printf '  driver: sqlite\n'
    printf '  sqlite:\n'
    printf '    path: %s\n' "$(yaml_quote '/app/data/backend.db')"
    printf 'runtimeStore:\n'
    printf '  driver: memory\n'
    printf 'media:\n'
    printf '  driver: local\n'
    printf '  local:\n'
    printf '    path: %s\n' "$(yaml_quote '/app/data/media')"
  } > "$config_tmp"
  chmod 0600 "$config_tmp"
  mv "$config_tmp" "$config_source"
fi

mkdir -p /app/data
cp "$config_source" /app/config.yaml
chown grok2api:grok2api /app/config.yaml /app/data
chmod 0600 /app/config.yaml

[ "$#" -gt 0 ] || set -- /app/grok2api --config /app/config.yaml
exec su-exec grok2api:grok2api "$@" --listen "0.0.0.0:${port}"

