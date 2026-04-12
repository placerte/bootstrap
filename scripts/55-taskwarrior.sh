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

TASKWARRIOR_VERSION="3.4.2"
SOURCE_DIR="$BUILD_ROOT/taskwarrior"

log "Cloning Taskwarrior v${TASKWARRIOR_VERSION} source"
git clone --depth 1 --branch "v${TASKWARRIOR_VERSION}" https://github.com/GothenburgBitFactory/taskwarrior.git "$SOURCE_DIR"

if [[ ! -d "$SOURCE_DIR" || ! -f "$SOURCE_DIR/CMakeLists.txt" ]]; then
  fail "Could not find cloned Taskwarrior source directory"
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
