#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

ASSUME_YES="${1:-false}"
CURRENT_HOSTNAME="$(hostname 2>/dev/null || true)"
TARGET_HOSTNAME=""

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

printf 'Current hostname: %s\n' "${CURRENT_HOSTNAME:-unknown}"

if [[ "$ASSUME_YES" == "true" ]]; then
  warn "Non-interactive mode detected, skipping hostname change prompt."
  exit 0
fi

if ! prompt_yes_no_local "Do you want to change the hostname now?" n; then
  echo "Leaving hostname unchanged."
  exit 0
fi

read -r -p "Enter new hostname: " TARGET_HOSTNAME

if [[ -z "$TARGET_HOSTNAME" ]]; then
  warn "No hostname entered, leaving hostname unchanged."
  exit 0
fi

if [[ "$TARGET_HOSTNAME" == "$CURRENT_HOSTNAME" ]]; then
  echo "Hostname already set to $TARGET_HOSTNAME."
  exit 0
fi

log "Updating hostname to $TARGET_HOSTNAME"
sudo hostnamectl set-hostname "$TARGET_HOSTNAME"

if grep -qE '^127\.0\.1\.1\s+' /etc/hosts; then
  sudo sed -i -E "s/^127\.0\.1\.1\s+.*/127.0.1.1   $TARGET_HOSTNAME/" /etc/hosts
else
  printf '127.0.1.1   %s\n' "$TARGET_HOSTNAME" | sudo tee -a /etc/hosts >/dev/null
fi

success "Hostname updated"
echo "You may want to reconnect your shell/SSH session so prompts and session metadata refresh cleanly."
