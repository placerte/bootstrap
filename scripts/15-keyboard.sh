#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

LAYOUT="ca"
VARIANT="multix"
PLATFORM="${1:-debian}"
HYPR_DIR="${HYPR_DIR:-$HOME/.config/hypr}"
INPUT_LUA="$HYPR_DIR/input.lua"
INPUT_CONF="$HYPR_DIR/input.conf"
MARKER_BEGIN="-- >>> bootstrap Canadian Multilingual keyboard >>>"
MARKER_END="-- <<< bootstrap Canadian Multilingual keyboard <<<"
LEGACY_BEGIN="# >>> bootstrap Canadian Multilingual keyboard >>>"
LEGACY_END="# <<< bootstrap Canadian Multilingual keyboard <<<"

configured_lua() {
  [[ -r "$INPUT_LUA" ]] && grep -Eq "kb_layout[[:space:]]*=[[:space:]]*['\"]ca['\"]" "$INPUT_LUA" &&
    grep -Eq "kb_variant[[:space:]]*=[[:space:]]*['\"]multix['\"]" "$INPUT_LUA"
}

configured_conf() {
  [[ -r "$INPUT_CONF" ]] && grep -Eq "kb_layout[[:space:]]*=[[:space:]]*ca([,[:space:]]|$)" "$INPUT_CONF" &&
    grep -Eq "kb_variant[[:space:]]*=[[:space:]]*multix([,[:space:]]|$)" "$INPUT_CONF"
}

configured_debian() {
  command -v localectl >/dev/null 2>&1 || return 1
  local status
  status="$(localectl status 2>/dev/null || true)"
  [[ "$status" == *"X11 Layout: ca"* || "$status" == *"X11 Layout: ca,"* ]] &&
    [[ "$status" == *"X11 Variant: multix"* ]]
}

configure_debian() {
  if ! command -v localectl >/dev/null 2>&1; then
    fail "Debian keyboard setup requires localectl (systemd-localed)"
    return 1
  fi
  if configured_debian; then
    success "Canadian Multilingual keyboard layout is already configured"
    return 0
  fi
  log "Configuring Canadian Multilingual keyboard layout with localectl"
  sudo localectl set-x11-keymap "$LAYOUT" pc105 "$VARIANT"

  # Configure the virtual console too when this XKB keymap is available. Some
  # Debian images do not ship a matching console map, so this is best-effort.
  local console_map
  console_map="$(localectl list-keymaps 2>/dev/null | awk '/^ca-multix(-1)?$/ { print; exit }' || true)"
  if [[ -n "$console_map" ]]; then
    sudo localectl set-keymap "$console_map"
  fi
  success "Canadian Multilingual keyboard layout ($LAYOUT/$VARIANT) configured"
}

backup_once() {
  local file="$1"
  [[ -e "$file" ]] || return 0
  local backup="${file}.bootstrap-keyboard-prechange"
  [[ -e "$backup" ]] || cp -p "$file" "$backup"
}

write_lua() {
  mkdir -p "$HYPR_DIR"
  backup_once "$INPUT_LUA"
  local tmp
  tmp="$(mktemp)"
  if [[ -r "$INPUT_LUA" ]]; then
    awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" \
      '$0 == begin { skip=1; next } $0 == end { skip=0; next } !skip { print }' \
      "$INPUT_LUA" >"$tmp"
  fi
  cat >>"$tmp" <<EOF

$MARKER_BEGIN
hl.config({
  input = {
    kb_layout = "$LAYOUT",
    kb_variant = "$VARIANT",
  },
})
$MARKER_END
EOF
  chmod 0644 "$tmp"
  mv "$tmp" "$INPUT_LUA"
}

write_legacy_conf() {
  mkdir -p "$HYPR_DIR"
  backup_once "$INPUT_CONF"
  local tmp
  tmp="$(mktemp)"
  if [[ -r "$INPUT_CONF" ]]; then
    awk -v begin="$LEGACY_BEGIN" -v end="$LEGACY_END" \
      '$0 == begin { skip=1; next } $0 == end { skip=0; next } !skip { print }' \
      "$INPUT_CONF" >"$tmp"
  fi
  cat >>"$tmp" <<EOF

$LEGACY_BEGIN
input {
    kb_layout = $LAYOUT
    kb_variant = $VARIANT
}
$LEGACY_END
EOF
  chmod 0644 "$tmp"
  mv "$tmp" "$INPUT_CONF"
}

if [[ "$PLATFORM" == "debian" ]]; then
  configure_debian
  exit $?
fi

if [[ "$PLATFORM" != "omarchy" ]]; then
  fail "Unsupported platform for keyboard setup: $PLATFORM"
  exit 1
fi

if configured_lua || configured_conf; then
  success "Canadian Multilingual keyboard layout is already configured"
  exit 0
fi

if [[ -e "$INPUT_LUA" || ! -e "$INPUT_CONF" ]]; then
  log "Configuring Canadian Multilingual keyboard layout in $INPUT_LUA"
  write_lua
else
  log "Configuring Canadian Multilingual keyboard layout in $INPUT_CONF"
  write_legacy_conf
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  hyprctl keyword input:kb_layout "$LAYOUT" >/dev/null 2>&1 || true
  hyprctl keyword input:kb_variant "$VARIANT" >/dev/null 2>&1 || true
fi
success "Canadian Multilingual keyboard layout ($LAYOUT/$VARIANT) configured"
