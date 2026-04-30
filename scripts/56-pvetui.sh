#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

PVETUI_VERSION="1.3.2"
PVETUI_ARCH="amd64"
PVETUI_DEB="pvetui_${PVETUI_VERSION}_linux_${PVETUI_ARCH}.deb"
PVETUI_URL="https://github.com/devnullvoid/pvetui/releases/download/v${PVETUI_VERSION}/${PVETUI_DEB}"

if [[ "$(dpkg --print-architecture)" != "$PVETUI_ARCH" ]]; then
  warn "Skipping pvetui install: this step currently supports only ${PVETUI_ARCH}."
  exit 0
fi

if dpkg-query -W -f='${Status} ${Version}\n' pvetui 2>/dev/null | grep -q "install ok installed ${PVETUI_VERSION}"; then
  success "pvetui ${PVETUI_VERSION} is already installed"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log "Downloading pvetui v${PVETUI_VERSION}"
download_to_file "$PVETUI_URL" "$TMP_DIR/$PVETUI_DEB"

log "Installing pvetui"
sudo apt install -y "$TMP_DIR/$PVETUI_DEB"

if command -v pvetui >/dev/null 2>&1; then
  pvetui --version || true
fi

success "pvetui installation complete"