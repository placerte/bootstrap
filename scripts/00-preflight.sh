#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-headless}"

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
else
  C_RESET=""
  C_DIM=""
  C_YELLOW=""
  C_RED=""
fi

if [[ "${EUID}" -eq 0 ]]; then
  printf '%sPlease run this script as a normal user with sudo access, not as root.%s\n' "$C_RED" "$C_RESET" >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  printf '%ssudo is required but was not found.%s\n' "$C_RED" "$C_RESET" >&2
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  printf '%sThis bootstrap currently targets apt-based Debian systems.%s\n' "$C_RED" "$C_RESET" >&2
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "debian" ]]; then
  printf '%sWarning:%s expected Debian, found ID=%s.\n' "$C_YELLOW" "$C_RESET" "${ID:-unknown}"
fi

printf 'Detected OS      : %s\n' "${PRETTY_NAME:-unknown}"
printf 'Selected profile : %s\n' "$PROFILE"
printf 'TERM             : %s\n' "${TERM:-unset}"

echo
echo "Hostname sanity check"
printf '%sIf this machine came from a Proxmox template, verify the hostname now.%s\n' "$C_DIM" "$C_RESET"
hostnamectl || true
hostname || true
