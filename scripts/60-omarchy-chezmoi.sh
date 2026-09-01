#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

DOTFILES_REPO="${1:?dotfiles repo URL required}"
APPLY_CHEZMOI="${2:-false}"

resolve_chezmoi() {
  local candidate
  for candidate in \
    "$HOME/.local/bin/chezmoi" \
    "$HOME/bin/chezmoi"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  command -v chezmoi 2>/dev/null
}

chezmoi_bin="$(resolve_chezmoi || true)"
if [[ -z "$chezmoi_bin" ]]; then
  log "Installing chezmoi through Omarchy"
  omarchy pkg add chezmoi
  chezmoi_bin="$(resolve_chezmoi || true)"
fi

if [[ -z "$chezmoi_bin" ]]; then
  fail "chezmoi installation did not provide an executable"
  exit 1
fi

success "chezmoi is available at $chezmoi_bin"

if [[ "$APPLY_CHEZMOI" == "true" ]]; then
  log "Initializing and applying the configured dotfiles repository"
  "$chezmoi_bin" init --apply "$DOTFILES_REPO"
  success "chezmoi configuration applied"
else
  echo "Dotfiles were not applied. Use --apply-chezmoi to opt in."
fi
