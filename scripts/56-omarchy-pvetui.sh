#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# GitHub issue #9: pvetui is available in the AUR. Never pass a Debian artifact
# to pacman or attempt to translate it on Omarchy.
if omarchy pkg present pvetui; then
  success "pvetui is already installed"
  exit 0
fi

if ! omarchy pkg aur accessible; then
  fail "pvetui requires AUR access on Omarchy"
  echo "Retry when the AUR is reachable, or omit --with-pvetui." >&2
  exit 1
fi

log "Installing pvetui from the AUR"
omarchy pkg aur add pvetui
success "pvetui is installed"
