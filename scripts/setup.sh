#!/bin/sh

# Quiet, deterministic setup that logs to stderr and outputs ONLY final JSON to stdout

echo "Installing Python virtual environment and dependencies..." >&2
PYTHON_BIN="python3"

# Create venv
${PYTHON_BIN} -m venv .venv > /dev/null 2>&1 || { echo "Failed to create venv" >&2; exit 1; }

# Activate venv
. .venv/bin/activate >/dev/null 2>&1 || { echo "Failed to activate venv" >&2; exit 1; }

# Upgrade pip and install deps
echo "Upgrading pip and installing requirements..." >&2
pip install --upgrade pip > /dev/null 2>&1 || { echo "pip upgrade failed" >&2; exit 1; }
if [ -f requirements.txt ]; then
  pip install -r requirements.txt > /dev/null 2>&1 || { echo "requirements install failed" >&2; exit 1; }
fi

# Optionally install the package itself if pyproject/setup exists
if [ -f pyproject.toml ] || [ -f setup.py ]; then
  echo "Installing project package (optional)..." >&2
  pip install . > /dev/null 2>&1 || echo "Package install failed (continuing)" >&2
fi

# Optional OAuth2 fetch (safe no-op if vars absent)
if [ -n "$API_KEY" ] && [ -n "$API_BASE_URL" ] && [ -n "$HIVE_INSTANCE_ID" ]; then
  echo "Fetching OAuth2 config (optional)..." >&2
  if curl -s -X GET "$API_BASE_URL/api/hive-instances/$HIVE_INSTANCE_ID/oauth2-config" \
    -H "x-api-key: $API_KEY" > oauth_response.json 2>/dev/null && [ -s oauth_response.json ]; then
    command -v jq >/dev/null 2>&1 && jq '.credentials' oauth_response.json > .gcp-saved-tokens.json 2>/dev/null || true
    command -v jq >/dev/null 2>&1 && jq '{ installed: .oauthKeys }' oauth_response.json > gcp-oauth.keys.json 2>/dev/null || true
    rm -f oauth_response.json
  else
    echo "OAuth2 config not available or fetch failed (continuing)" >&2
  fi
fi

echo "Setup complete" >&2

# Emit ONLY the final JSON to stdout
cat <<EOF
{
  "command": "$(pwd)/.venv/bin/python3",
  "args": ["$(pwd)/server.py"],
  "env": {
    "TENANT_ID": "${TENANT_ID}",
    "CLIENT_ID": "${CLIENT_ID}",
    "CLIENT_SECRET": "${CLIENT_SECRET}",
    "SITE_URL": "${SITE_URL}",
    "USERNAME": "${USERNAME}",
    "PASSWORD": "${PASSWORD}",
    "DEBUG": "${DEBUG}"
  },
  "cwd": "$(pwd)"
}
EOF


