#!/usr/bin/env bash
set -euo pipefail

os_release="${BOOTSTRAP_OS_RELEASE:-/etc/os-release}"
if [[ ! -r "$os_release" ]]; then
  echo "Cannot verify Debian GUI compatibility: $os_release is unreadable." >&2
  exit 1
fi

os_id="$(. "$os_release"; printf '%s' "${ID:-}")"

# GitHub issue #6: this component installs an Xorg/i3/SDDM desktop and must
# never execute on Omarchy's Hyprland/Wayland session, even when called directly.
if [[ "$os_id" != "debian" ]]; then
  echo "The GUI package component is Debian-only (detected: ${os_id:-unknown})." >&2
  exit 1
fi

sudo apt update
sudo apt install -y \
  xorg \
  i3-wm \
  i3lock \
  picom \
  sddm \
  polybar \
  kitty \
  feh \
  rofi \
  keynav \
  brightnessctl \
  lxappearance \
  arc-theme \
  papirus-icon-theme \
  breeze-cursor-theme \
  breeze-icon-theme
