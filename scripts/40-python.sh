#!/usr/bin/env bash
set -euo pipefail

sudo apt install -y python3 python3-venv python3-tk python3-pip

if [[ ! -x "$HOME/.local/bin/uv" ]] && ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
