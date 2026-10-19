#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

NVIM_ARCH="$(release_arch)"
NVIM_DIR="nvim-linux-${NVIM_ARCH}"
download_to_file "https://github.com/neovim/neovim/releases/latest/download/${NVIM_DIR}.tar.gz" "$TMP_DIR/${NVIM_DIR}.tar.gz"
tar -xzf "$TMP_DIR/${NVIM_DIR}.tar.gz" -C "$TMP_DIR"
sudo rm -rf /opt/nvim
sudo mv "$TMP_DIR/$NVIM_DIR" /opt/nvim
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

sudo apt install -y sc-im
