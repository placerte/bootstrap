#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

BOOTSTRAP_MACHINE_ARCH=x86_64
[[ "$(release_arch)" == "x86_64" ]]
echo "ok - x86-64 selects x86-64 release assets"

BOOTSTRAP_MACHINE_ARCH=aarch64
[[ "$(release_arch)" == "arm64" ]]
echo "ok - Raspberry Pi OS 64-bit selects ARM64 release assets"

BOOTSTRAP_MACHINE_ARCH=armv7l
if release_arch >/dev/null 2>&1; then
  echo "not ok - unsupported 32-bit ARM was accepted" >&2
  exit 1
fi
echo "ok - 32-bit ARM fails before installing incompatible binaries"

rg -q 'arm64\) YAZI_ARCH="aarch64"' "$ROOT_DIR/scripts/install-yazi.sh"
rg -q 'RivoLink/leaf/main/scripts/install.sh' "$ROOT_DIR/scripts/install-leaf.sh"
rg -q 'NVIM_DIR="nvim-linux-\$\{NVIM_ARCH\}"' "$ROOT_DIR/scripts/45-editors.sh"
echo "ok - Leaf, Yazi, and Neovim installers use supported upstream release paths"
