#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

ASSUME_YES="${1:-false}"
ACTIVATE_TAILSCALE="${2:-false}"

prompt_activate() {
  local reply
  read -r -p "Run 'sudo tailscale up' and authenticate this machine now? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

backend_state() {
  local status_json
  status_json="$(tailscale status --json 2>/dev/null)" || {
    echo "Unavailable"
    return 0
  }

  if command -v jq >/dev/null 2>&1; then
    jq -r '.BackendState // "Unknown"' <<<"$status_json"
  else
    sed -n 's/.*"BackendState"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$status_json" | head -n 1
  fi
}

# Omarchy's high-level service installer currently joins a tailnet immediately.
# GitHub issue #8 keeps package/service setup separate from authentication.
if ! command -v tailscale >/dev/null 2>&1; then
  log "Installing Tailscale through Omarchy"
  omarchy pkg add tailscale
fi

if ! command -v tailscale >/dev/null 2>&1; then
  fail "Tailscale installation did not provide the tailscale command"
  exit 1
fi

if ! systemctl is-active --quiet tailscaled.service >/dev/null 2>&1; then
  log "Enabling and starting tailscaled"
  sudo systemctl enable --now tailscaled.service
fi

state="$(backend_state)"
case "$state" in
  Running)
    success "Tailscale is installed, running, and connected"
    exit 0
    ;;
  NeedsLogin)
    warn "Tailscale is installed and running but needs authentication"
    ;;
  Stopped|NoState|Unavailable|Unknown|"")
    warn "Tailscale is installed but not connected (state: ${state:-Unknown})"
    ;;
  *)
    warn "Tailscale backend state: $state"
    ;;
esac

should_activate="false"
if [[ "$ACTIVATE_TAILSCALE" == "true" ]]; then
  should_activate="true"
elif [[ "$ASSUME_YES" != "true" ]] && prompt_activate; then
  should_activate="true"
fi

if [[ "$should_activate" == "true" ]]; then
  sudo tailscale up
  success "Tailscale activation started"
else
  echo "Leaving Tailscale installed and started without changing tailnet authentication."
fi
