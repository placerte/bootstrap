#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

LEAF_INSTALL_DIR="${LEAF_INSTALL_DIR:-$HOME/.local/bin}"

if command -v leaf >/dev/null 2>&1 || [[ -x "$LEAF_INSTALL_DIR/leaf" ]]; then
  echo "Leaf already installed, skipping."
  exit 0
fi

installer="$(mktemp)"
cleanup() {
  rm -f "$installer"
}
trap cleanup EXIT

download_to_file \
  "https://raw.githubusercontent.com/RivoLink/leaf/main/scripts/install.sh" \
  "$installer"
sh "$installer" "$LEAF_INSTALL_DIR"

echo "Leaf installed successfully."
