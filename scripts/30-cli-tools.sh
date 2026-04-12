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
  tealdeer \
  texlive-xetex \
  texlive-latex-extra \
  latexmk

curl -fsSL https://tailscale.com/install.sh | sh
