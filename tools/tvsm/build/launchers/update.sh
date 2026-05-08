#!/usr/bin/env bash
set -euo pipefail
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command "& '$BUNDLE_DIR/tvsm.ps1' update apply \"$@\""
else
  echo "Error: pwsh not found on PATH. Please install PowerShell." >&2
  exit 1
fi
