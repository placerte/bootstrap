#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -L -o "$TMP_DIR/nvim-linux-x86_64.tar.gz" https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
tar -xzf "$TMP_DIR/nvim-linux-x86_64.tar.gz" -C "$TMP_DIR"
sudo rm -rf /opt/nvim
sudo mv "$TMP_DIR/nvim-linux-x86_64" /opt/nvim
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

sudo apt install -y sc-im
