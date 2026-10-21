#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

ASSUME_YES="${1:-false}"
AUTHENTICATE="${2:-false}"

if ! command -v hermes >/dev/null 2>&1; then
  log "Installing Hermes Agent"
  download_to_stdout https://hermes-agent.nousresearch.com/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
else
  success "Hermes Agent is already installed"
fi

if ! command -v hermes >/dev/null 2>&1; then
  fail "Hermes installation did not provide the hermes command"
  exit 1
fi

if hermes auth list openai-codex 2>/dev/null | grep -Eq '[1-9][0-9]* credential'; then
  success "Hermes already has OpenAI Codex authentication"
  exit 0
fi

if [[ "$AUTHENTICATE" == "true" ]]; then
  hermes auth add openai-codex
elif [[ "$ASSUME_YES" == "true" ]]; then
  warn "Hermes is installed but not authenticated; run: hermes auth add openai-codex"
else
  read -r -p "Authenticate Hermes with OpenAI using a device code now? [Y/n] " reply
  if [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]; then
    hermes auth add openai-codex
  else
    warn "Hermes authentication skipped; run: hermes auth add openai-codex"
  fi
fi
