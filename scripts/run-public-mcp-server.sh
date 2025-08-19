#!/usr/bin/env bash

set -euo pipefail

SERVER_NAME="${1:-sharepoint-mcp}"
SHIFTED=0

echo "[run-wrapper] Server name: ${SERVER_NAME}" >&2

# Shift server name if provided
if [[ "$#" -ge 1 ]]; then
  shift
  SHIFTED=1
fi

RUN_SETUP=false
for arg in "$@"; do
  if [[ "$arg" == "--with-setup" ]]; then
    RUN_SETUP=true
    break
  fi
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SETUP_JSON=""
if [[ "$RUN_SETUP" == true ]]; then
  echo "[run-wrapper] Running setup.sh..." >&2
  if [[ ! -x "scripts/setup.sh" ]]; then
    chmod +x scripts/setup.sh || true
  fi
  # Capture ONLY stdout from setup.sh; all logs must go to stderr per setup.sh contract
  if ! SETUP_JSON=$(bash scripts/setup.sh); then
    echo "[run-wrapper] setup.sh failed" >&2
    exit 1
  fi
else
  echo "[run-wrapper] --with-setup not provided; attempting to run using existing environment" >&2
  # Try to synthesize a minimal JSON if setup is skipped
  SETUP_JSON=$(cat <<EOF
{"command":"$(pwd)/.venv/bin/python3","args":["$(pwd)/server.py"],"env":{},"cwd":"$(pwd)"}
EOF
)
fi

# Use Python to parse JSON and exec target command
python3 - "$SERVER_NAME" <<'PY'
import json, os, sys, subprocess

server_name = sys.argv[1] if len(sys.argv) > 1 else "sharepoint-mcp"

raw = sys.stdin.read()
try:
    cfg = json.loads(raw)
except Exception as e:
    print(f"[run-wrapper] Invalid JSON from setup: {e}", file=sys.stderr)
    sys.exit(1)

command = cfg.get("command")
args = cfg.get("args", [])
env = cfg.get("env", {})
cwd = cfg.get("cwd") or os.getcwd()

if not command:
    print("[run-wrapper] 'command' missing in setup JSON", file=sys.stderr)
    sys.exit(1)

# Export env vars
for k, v in env.items():
    if v is None:
        v = ""
    os.environ[str(k)] = str(v)

os.chdir(cwd)

print(f"[run-wrapper] Executing: {command} {' '.join(args)}", file=sys.stderr)
os.execv(command, [command] + list(args))
PY


