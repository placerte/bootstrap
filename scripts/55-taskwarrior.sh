#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

ASSUME_YES="${1:-false}"

prompt_yes_no_local() {
  local prompt="$1"
  local default="${2:-n}"
  local reply

  if [[ "$ASSUME_YES" == "true" ]]; then
    return 1
  fi

  if [[ "$default" == "y" ]]; then
    read -r -p "$prompt [Y/n] " reply
    [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]
  else
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
  fi
}

if ! prompt_yes_no_local "Do you want to build and install the latest Taskwarrior from source now?" n; then
  echo "Skipping Taskwarrior source build."
  exit 0
fi

log "Installing Taskwarrior build dependencies"
sudo apt update
sudo apt install -y \
  cmake \
  g++ \
  git \
  libgnutls28-dev \
  libuuid1 \
  make \
  pkg-config \
  uuid-dev

BUILD_ROOT="$(mktemp -d)"
trap 'rm -rf "$BUILD_ROOT"' EXIT

log "Resolving latest Taskwarrior release tarball"
LATEST_TARBALL_URL="$(download_to_stdout https://api.github.com/repos/GothenburgBitFactory/taskwarrior/releases/latest | grep 'tarball_url' | head -n 1 | cut -d '"' -f 4)"

if [[ -z "$LATEST_TARBALL_URL" ]]; then
  fail "Could not determine latest Taskwarrior release tarball URL"
  exit 1
fi

log "Downloading latest Taskwarrior release source tarball"
download_to_file "$LATEST_TARBALL_URL" "$BUILD_ROOT/taskwarrior.tar.gz"

tar -xzf "$BUILD_ROOT/taskwarrior.tar.gz" -C "$BUILD_ROOT"
SOURCE_DIR="$(find "$BUILD_ROOT" -maxdepth 1 -type d -name 'taskwarrior-*' | head -n 1)"

if [[ -z "$SOURCE_DIR" ]]; then
  fail "Could not find extracted Taskwarrior source directory"
  exit 1
fi

log "Configuring Taskwarrior build"
cmake -S "$SOURCE_DIR" -B "$BUILD_ROOT/build" -DCMAKE_BUILD_TYPE=Release

log "Building Taskwarrior"
cmake --build "$BUILD_ROOT/build" -j"$(nproc)"

log "Installing Taskwarrior"
sudo cmake --install "$BUILD_ROOT/build"

if command -v task >/dev/null 2>&1; then
  task --version || true
fi

success "Taskwarrior build and installation complete"
