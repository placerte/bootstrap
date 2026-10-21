#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

ASSUME_YES="${1:-false}"
AUTHENTICATE="${2:-false}"

if ! command -v codex >/dev/null 2>&1; then
  log "Installing the latest Codex CLI"
  sudo npm install -g @openai/codex@latest
else
  success "Codex CLI is already installed"
fi

if codex login status >/dev/null 2>&1; then
  success "Codex is already authenticated"
  exit 0
fi

if [[ "$AUTHENTICATE" == "true" ]]; then
  codex login --device-auth
elif [[ "$ASSUME_YES" == "true" ]]; then
  warn "Codex is installed but not authenticated; run: codex login --device-auth"
else
  read -r -p "Authenticate Codex with an OpenAI device code now? [Y/n] " reply
  if [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]; then
    codex login --device-auth
  else
    warn "Codex authentication skipped; run: codex login --device-auth"
  fi
fi
