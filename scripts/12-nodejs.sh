#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

NODE_MAJOR=24

node_major() {
  node --version 2>/dev/null | sed -n 's/^v\([0-9][0-9]*\).*/\1/p'
}

if command -v node >/dev/null 2>&1 && [[ "$(node_major)" -ge "$NODE_MAJOR" ]]; then
  success "Node.js $(node --version) already satisfies the v${NODE_MAJOR}+ requirement"
  exit 0
fi

log "Installing Node.js ${NODE_MAJOR}.x from NodeSource"
setup_script="$(mktemp)"
trap 'rm -f "$setup_script"' EXIT
download_to_file "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" "$setup_script"
sudo -E bash "$setup_script"
sudo apt install -y nodejs

installed_major="$(node_major)"
if [[ -z "$installed_major" || "$installed_major" -lt "$NODE_MAJOR" ]]; then
  fail "Node.js ${NODE_MAJOR}+ was not installed successfully"
  exit 1
fi

success "Installed Node.js $(node --version) and npm $(npm --version)"
