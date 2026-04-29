#!/usr/bin/env bash
set -euo pipefail

if command -v yazi >/dev/null 2>&1 && command -v ya >/dev/null 2>&1; then
  echo "Yazi already installed, skipping."
  exit 0
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cd "$TMP_DIR"

wget -q https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip
unzip -q yazi-*.zip

DIR="$(find . -maxdepth 1 -type d -name 'yazi-*' | head -n 1)"
if [[ -z "$DIR" ]]; then
  echo "Could not find extracted yazi directory" >&2
  exit 1
fi

sudo mv "$DIR/yazi" "$DIR/ya" /usr/local/bin/

echo "Yazi installed successfully."
