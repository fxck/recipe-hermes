#!/usr/bin/env sh
# Hermes dashboard launcher with ONE switch: DASHBOARD_MODE
#
#   private (default) — secure-by-default. Dashboard binds 0.0.0.0 but you keep the
#                       Zerops subdomain DISABLED, so it's reachable only on the project
#                       network: `zcli vpn up` then http://hermes:9119
#
#   oauth             — public demo. Keep the subdomain ENABLED; Hermes gates the UI
#                       behind OAuth login. Requires these env secrets:
#                         DASHBOARD_OAUTH_PROVIDER       (github | google; default github)
#                         DASHBOARD_OAUTH_CLIENT_ID
#                         DASHBOARD_OAUTH_CLIENT_SECRET
#                         HERMES_DASHBOARD_PUBLIC_URL    (the public https subdomain, for OAuth redirect)
set -eu

PORT="${HERMES_DASHBOARD_PORT:-9119}"
HERMES="python3 /var/www/vendor/bin/hermes"

case "${DASHBOARD_MODE:-private}" in
  oauth)
    : "${DASHBOARD_OAUTH_CLIENT_ID:?oauth mode needs DASHBOARD_OAUTH_CLIENT_ID}"
    : "${DASHBOARD_OAUTH_CLIENT_SECRET:?oauth mode needs DASHBOARD_OAUTH_CLIENT_SECRET}"
    : "${HERMES_DASHBOARD_PUBLIC_URL:?oauth mode needs HERMES_DASHBOARD_PUBLIC_URL}"
    PROVIDER="${DASHBOARD_OAUTH_PROVIDER:-github}"
    echo "[dashboard] mode=oauth provider=$PROVIDER (gated, public)"
    $HERMES config set "dashboard.oauth.provider"      "$PROVIDER"                     >/dev/null 2>&1 || true
    $HERMES config set "dashboard.oauth.client_id"     "$DASHBOARD_OAUTH_CLIENT_ID"    >/dev/null 2>&1 || true
    $HERMES config set "dashboard.oauth.client_secret" "$DASHBOARD_OAUTH_CLIENT_SECRET" >/dev/null 2>&1 || true
    exec $HERMES dashboard --host 0.0.0.0 --port "$PORT" --no-open --skip-build --insecure
    ;;
  private|*)
    echo "[dashboard] mode=private (internal/VPN only — keep the Zerops subdomain disabled)"
    exec $HERMES dashboard --host 0.0.0.0 --port "$PORT" --no-open --skip-build --insecure
    ;;
esac
