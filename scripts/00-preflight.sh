#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

PLATFORM="${1:-debian}"
PROFILE="${2:-headless}"

if [[ "${EUID}" -eq 0 ]]; then
  printf '%sPlease run this script as a normal user with sudo access, not as root.%s\n' "$C_RED" "$C_RESET" >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  printf '%ssudo is required but was not found.%s\n' "$C_RED" "$C_RESET" >&2
  exit 1
fi

. /etc/os-release
case "$PLATFORM" in
  debian)
    if ! command -v apt >/dev/null 2>&1; then
      printf '%sThe Debian bootstrap requires apt.%s\n' "$C_RED" "$C_RESET" >&2
      exit 1
    fi
    [[ "${ID:-}" == "debian" ]] || printf '%sWarning:%s expected Debian, found ID=%s.\n' "$C_YELLOW" "$C_RESET" "${ID:-unknown}"
    ;;
  omarchy)
    if ! command -v omarchy >/dev/null 2>&1; then
      printf '%sThe Omarchy bootstrap requires the omarchy command.%s\n' "$C_RED" "$C_RESET" >&2
      exit 1
    fi
    [[ "${ID:-}" == "omarchy" ]] || printf '%sWarning:%s expected Omarchy, found ID=%s.\n' "$C_YELLOW" "$C_RESET" "${ID:-unknown}"
    ;;
  *)
    printf '%sUnsupported platform: %s%s\n' "$C_RED" "$PLATFORM" "$C_RESET" >&2
    exit 1
    ;;
esac

printf 'Detected OS      : %s\n' "${PRETTY_NAME:-unknown}"
printf 'Selected platform: %s\n' "$PLATFORM"
printf 'Selected profile : %s\n' "$PROFILE"
printf 'TERM             : %s\n' "${TERM:-unset}"

echo
echo "Hostname sanity check"
printf '%sIf this machine came from a Proxmox template, verify the hostname now.%s\n' "$C_DIM" "$C_RESET"
# hostnamectl may wait on a user/session D-Bus on a fresh graphical install.
# Keep this informational check bounded so bootstrap cannot appear hung before
# the first real component runs.
if command -v timeout >/dev/null 2>&1; then
  timeout 3s hostnamectl || true
else
  hostnamectl || true
fi
hostname || true
