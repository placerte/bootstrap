#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

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

case "$(release_arch)" in
  x86_64) YAZI_ARCH="x86_64" ;;
  arm64) YAZI_ARCH="aarch64" ;;
esac

YAZI_ARCHIVE="yazi-${YAZI_ARCH}-unknown-linux-gnu.zip"
download_to_file "https://github.com/sxyazi/yazi/releases/latest/download/$YAZI_ARCHIVE" "$YAZI_ARCHIVE"
unzip -q "$YAZI_ARCHIVE"

DIR="$(find . -maxdepth 1 -type d -name 'yazi-*' | head -n 1)"
if [[ -z "$DIR" ]]; then
  echo "Could not find extracted yazi directory" >&2
  exit 1
fi

sudo mv "$DIR/yazi" "$DIR/ya" /usr/local/bin/

echo "Yazi installed successfully."
