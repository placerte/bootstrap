#!/usr/bin/env bash
set -euo pipefail

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

curl -fsSL https://tailscale.com/install.sh | sh
