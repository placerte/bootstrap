#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# GitHub issue #10: this list mirrors only explicit "Include" decisions in the
# reviewed bootstrap inventory. Debian package names and Omarchy defaults do not
# belong here. Kitty is handled by the dedicated terminal component.
OMARCHY_PACKAGES=(
  imagemagick # Yazi image and font previews
  yazi
)

if ! command -v omarchy >/dev/null 2>&1; then
  fail "The Omarchy package component requires the omarchy command"
  exit 1
fi

if omarchy pkg present "${OMARCHY_PACKAGES[@]}"; then
  success "Reviewed Omarchy packages are already installed"
  exit 0
fi

log "Installing missing reviewed Omarchy packages"
omarchy pkg add "${OMARCHY_PACKAGES[@]}"
success "Reviewed Omarchy packages are installed"
