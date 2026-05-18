#!/bin/sh
set -eu

escaped_api_base_url=$(
  printf '%s' "${API_BASE_URL:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'
)
escaped_api_cookie=$(
  printf '%s' "${API_COOKIE:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'
)

cat > /usr/share/nginx/html/env.js <<EOF
window.__APP_CONFIG__ = {
  apiBaseUrl: "${escaped_api_base_url}",
  cookie: "${escaped_api_cookie}"
};
EOF

exec nginx -g 'daemon off;'
