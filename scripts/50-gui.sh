#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y \
  xorg \
  i3-wm \
  i3lock \
  i3lock-color \
  picom \
  sddm \
  polybar \
  kitty \
  feh \
  rofi \
  keynav \
  lxappearance \
  arc-theme \
  papirus-icon-theme \
  breeze-cursor-theme \
  breeze-icon-theme
