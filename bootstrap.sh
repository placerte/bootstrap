#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"

PROFILE=""
WITH_CHEZMOI="false"
ASSUME_YES="false"
DOTFILES_REPO="https://github.com/placerte/dotfiles.git"
TOTAL_STEPS=6

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
else
  C_RESET=""
  C_BOLD=""
  C_DIM=""
  C_BLUE=""
  C_CYAN=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
fi

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

print_banner() {
  printf '%s\n' "${C_CYAN}${C_BOLD}"
  printf '  ____              __        __                   __\n'
  printf ' / __ )____  ____  / /_______/ /__________ _____  / /\n'
  printf '/ __  / __ \/ __ \/ __/ ___/ __/ ___/ __ `/ __ \/ / \n'
  printf '/ /_/ / /_/ / /_/ / /_(__  ) /_/ /  / /_/ / /_/ / /  \n'
  printf '/_____/\____/\____/\__/____/\__/_/   \__,_/ .___/_/   \n'
  printf '                                         /_/         \n'
  printf '%s\n' "${C_RESET}"
  printf '%sFresh Debian machine bootstrap%s\n' "${C_DIM}" "${C_RESET}"
}

log() {
  printf '\n%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"
}

success() {
  printf '%s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"
}

warn() {
  printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
}

fail() {
  printf '%s✘%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
}

draw_rule() {
  printf '%s------------------------------------------------------------%s\n' "$C_DIM" "$C_RESET"
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

render_profile_menu() {
  clear || true
  print_banner
  draw_rule
  printf '%sSelect install profile%s\n\n' "$C_BOLD" "$C_RESET"
  printf '  %s1)%s headless  %sTerminal-first setup for servers, VMs, and minimal systems%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '  %s2)%s gui       %sHeadless setup plus Xorg, i3, kitty, polybar, and friends%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '\n'
}

prompt_profile() {
  if [[ -n "$PROFILE" ]]; then
    return 0
  fi

  if [[ "$ASSUME_YES" == "true" ]]; then
    PROFILE="headless"
    return 0
  fi

  local choice
  while true; do
    render_profile_menu
    read -r -p "Choice [1/2]: " choice
    case "${choice:-1}" in
      1) PROFILE="headless"; break ;;
      2) PROFILE="gui"; break ;;
      *) warn "Invalid choice, please select 1 or 2." ;;
    esac
  done
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
    fail "Invalid profile: $PROFILE"
    echo "Expected one of: headless, gui"
    exit 1
  fi
}

run_step() {
  local current="$1"
  local title="$2"
  local script="$3"
  shift 3 || true

  printf '\n%s[%s/%s]%s %s%s%s\n' "$C_DIM" "$current" "$TOTAL_STEPS" "$C_RESET" "$C_BOLD" "$title" "$C_RESET"
  draw_rule
  bash "$SCRIPTS_DIR/$script" "$@"
  success "$title complete"
}

main() {
  parse_args "$@"

  export TERM="${TERM:-xterm-256color}"

  print_banner
  prompt_profile

  if [[ "$PROFILE" == "gui" ]]; then
    TOTAL_STEPS=7
  fi
  if [[ "$WITH_CHEZMOI" == "true" ]]; then
    :
  fi

  if [[ "$WITH_CHEZMOI" != "true" ]]; then
    if prompt_yes_no "Install and initialize chezmoi as part of bootstrap?" y; then
      WITH_CHEZMOI="true"
    fi
  fi

  if [[ "$WITH_CHEZMOI" == "true" ]]; then
    if [[ "$PROFILE" == "gui" ]]; then
      TOTAL_STEPS=8
    else
      TOTAL_STEPS=7
    fi
  fi

  log "Bootstrap plan"
  echo "Profile      : $PROFILE"
  echo "chezmoi      : $WITH_CHEZMOI"
  echo "dotfiles repo: $DOTFILES_REPO"

  run_step 1 "Preflight checks" 00-preflight.sh "$PROFILE"
  run_step 2 "Base packages" 10-base-packages.sh
  run_step 3 "Shell setup" 20-shell.sh
  run_step 4 "CLI tools" 30-cli-tools.sh
  run_step 5 "Python tooling" 40-python.sh
  run_step 6 "Editors" 45-editors.sh

  local step=7
  if [[ "$PROFILE" == "gui" ]]; then
    run_step "$step" "GUI packages" 50-gui.sh
    step=$((step + 1))
  fi

  if [[ "$WITH_CHEZMOI" == "true" ]]; then
    run_step "$step" "chezmoi setup" 60-chezmoi.sh "$DOTFILES_REPO"
    step=$((step + 1))
  fi

  run_step "$step" "Postflight summary" 70-postflight.sh "$PROFILE" "$WITH_CHEZMOI"

  printf '\n%sBootstrap complete.%s\n' "$C_GREEN$C_BOLD" "$C_RESET"
}

main "$@"
