#!/usr/bin/env bash
set -euo pipefail

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

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

download_to_file() {
  local url="$1"
  local dest="$2"

  if have_cmd curl; then
    curl -fsSL --connect-timeout 10 --max-time 120 "$url" -o "$dest"
  elif have_cmd wget; then
    wget --inet4-only --timeout=15 --tries=3 -qO "$dest" "$url"
  else
    fail "Need wget or curl to download required resources"
    exit 1
  fi
}

download_to_stdout() {
  local url="$1"

  if have_cmd curl; then
    curl -fsSL --connect-timeout 10 --max-time 120 "$url"
  elif have_cmd wget; then
    wget --inet4-only --timeout=15 --tries=3 -qO- "$url"
  else
    fail "Need wget or curl to download required resources"
    exit 1
  fi
}

machine_arch() {
  printf '%s\n' "${BOOTSTRAP_MACHINE_ARCH:-$(uname -m)}"
}

release_arch() {
  case "$(machine_arch)" in
    x86_64|amd64) printf '%s\n' "x86_64" ;;
    aarch64|arm64) printf '%s\n' "arm64" ;;
    *)
      fail "Unsupported CPU architecture: $(machine_arch). This bootstrap currently supports x86-64 and 64-bit ARM."
      return 1
      ;;
  esac
}
