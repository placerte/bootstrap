#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-headless}"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Please run this script as a normal user with sudo access, not as root."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required but was not found."
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  echo "This bootstrap currently targets apt-based Debian systems."
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "debian" ]]; then
  echo "Warning: expected Debian, found ID=${ID:-unknown}."
fi

echo "Preflight OK"
echo "Detected OS: ${PRETTY_NAME:-unknown}"
echo "Selected profile: ${PROFILE}"
echo "TERM=${TERM:-unset}"

echo
echo "Hostname sanity check:"
hostnamectl || true
hostname || true

echo
echo "If this machine was cloned from a Proxmox template, verify the hostname now before going too far."
