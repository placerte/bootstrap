#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

sudo apt install -y \
  btop \
  fastfetch \
  lsd \
  fzf \
  zip \
  unzip \
  glow \
  tree \
  tealdeer

download_to_stdout https://tailscale.com/install.sh | sh
