#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# GitHub issue #11: Omarchy owns terminal installation, preference selection,
# and the base Kitty config. This component verifies those results but does not
# replace the config or edit packaged files under /usr/share/omarchy.
TERMINAL_PREFERENCE="${TERMINAL_PREFERENCE:-$HOME/.config/xdg-terminals.list}"
KITTY_CONFIG="${KITTY_CONFIG:-$HOME/.config/kitty/kitty.conf}"
KITTY_THEME_INCLUDE='include ~/.local/state/omarchy/current/theme/kitty.conf'
YAZI_PREVIEW_COMMANDS="${YAZI_PREVIEW_COMMANDS:-yazi ya magick}"

selected_terminal() {
  [[ -r "$TERMINAL_PREFERENCE" ]] || return 1
  sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$TERMINAL_PREFERENCE" | head -n 1
}

terminal_is_ready() {
  command -v kitty >/dev/null 2>&1 &&
    [[ "$(selected_terminal 2>/dev/null || true)" == "kitty.desktop" ]] &&
    [[ -r "$KITTY_CONFIG" ]] &&
    grep -Fqx "$KITTY_THEME_INCLUDE" "$KITTY_CONFIG"
}

if terminal_is_ready; then
  success "Kitty is already installed, themed, and selected"
else
  log "Installing and selecting Kitty through Omarchy"
  omarchy install terminal kitty
fi

if ! terminal_is_ready; then
  fail "Kitty did not become the themed Omarchy default"
  echo "Expected kitty.desktop in $TERMINAL_PREFERENCE and the Omarchy theme include in $KITTY_CONFIG." >&2
  exit 1
fi

read -r -a preview_commands <<<"$YAZI_PREVIEW_COMMANDS"
for command_name in "${preview_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "Yazi preview requirement is missing: $command_name"
    exit 1
  fi
done

if ! kitty +kitten icat --help >/dev/null 2>&1; then
  fail "Kitty's image protocol helper is unavailable"
  exit 1
fi

success "Kitty and Yazi image-preview support are ready"
