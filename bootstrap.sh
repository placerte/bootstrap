#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"

PROFILE=""
WITH_CHEZMOI="false"
ASSUME_YES="false"
DOTFILES_REPO="https://github.com/placerte/dotfiles.git"

usage() {
  cat <<'EOF'
Usage:
  bootstrap.sh [options]

Options:
  --profile <headless|gui>
  --with-chezmoi
  --dotfiles-repo <git-url>
  --yes
  --help
EOF
}

log() {
  printf '\n==> %s\n' "$*"
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local reply

  if [[ "$ASSUME_YES" == "true" ]]; then
    return 0
  fi

  if [[ "$default" == "y" ]]; then
    read -r -p "$prompt [Y/n] " reply
    [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]
  else
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
  fi
}

prompt_profile() {
  if [[ -n "$PROFILE" ]]; then
    return 0
  fi

  if [[ "$ASSUME_YES" == "true" ]]; then
    PROFILE="headless"
    return 0
  fi

  echo "Select install profile:"
  echo "  1) headless"
  echo "  2) gui"
  read -r -p "Choice [1/2]: " choice

  case "${choice:-1}" in
    1) PROFILE="headless" ;;
    2) PROFILE="gui" ;;
    *)
      echo "Invalid choice"
      exit 1
      ;;
  esac
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        PROFILE="$2"
        shift 2
        ;;
      --with-chezmoi)
        WITH_CHEZMOI="true"
        shift
        ;;
      --dotfiles-repo)
        DOTFILES_REPO="$2"
        shift 2
        ;;
      --yes)
        ASSUME_YES="true"
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  if [[ -n "$PROFILE" && "$PROFILE" != "headless" && "$PROFILE" != "gui" ]]; then
    echo "Invalid profile: $PROFILE"
    echo "Expected one of: headless, gui"
    exit 1
  fi
}

run_script() {
  local script="$1"
  shift || true
  bash "$SCRIPTS_DIR/$script" "$@"
}

main() {
  parse_args "$@"

  export TERM="${TERM:-xterm-256color}"

  prompt_profile

  if [[ "$WITH_CHEZMOI" != "true" ]]; then
    if prompt_yes_no "Install and initialize chezmoi as part of bootstrap?" y; then
      WITH_CHEZMOI="true"
    fi
  fi

  log "Starting bootstrap"
  log "Profile: $PROFILE"
  log "chezmoi: $WITH_CHEZMOI"
  log "dotfiles repo: $DOTFILES_REPO"

  run_script 00-preflight.sh "$PROFILE"
  run_script 10-base-packages.sh
  run_script 20-shell.sh
  run_script 30-cli-tools.sh
  run_script 40-python.sh
  run_script 45-editors.sh

  if [[ "$PROFILE" == "gui" ]]; then
    run_script 50-gui.sh
  fi

  if [[ "$WITH_CHEZMOI" == "true" ]]; then
    run_script 60-chezmoi.sh "$DOTFILES_REPO"
  fi

  run_script 70-postflight.sh "$PROFILE" "$WITH_CHEZMOI"

  log "Bootstrap complete"
}

main "$@"
