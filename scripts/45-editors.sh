#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

download_to_file https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz "$TMP_DIR/nvim-linux-x86_64.tar.gz"
tar -xzf "$TMP_DIR/nvim-linux-x86_64.tar.gz" -C "$TMP_DIR"
sudo rm -rf /opt/nvim
sudo mv "$TMP_DIR/nvim-linux-x86_64" /opt/nvim
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

sudo apt install -y sc-im
