#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

ASSUME_YES="${1:-false}"

prompt_yes_no_local() {
  local prompt="$1"
  local default="${2:-y}"
  local reply

  if [[ "$ASSUME_YES" == "true" ]]; then
    return 1
  fi

  if [[ "$default" == "y" ]]; then
    read -r -p "$prompt [Y/n] " reply
    [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]
  else
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
  fi
}

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

if command -v tailscale >/dev/null 2>&1; then
  if sudo tailscale status >/dev/null 2>&1; then
    echo "Tailscale already appears to be up."
  elif prompt_yes_no_local "Do you want to run 'sudo tailscale up' now?" y; then
    sudo tailscale up
  else
    echo "Leaving Tailscale installed but not brought up."
  fi
fi
