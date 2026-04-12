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

wget -qO- https://tailscale.com/install.sh | sh
