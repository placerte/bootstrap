#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

DOTFILES_REPO="${1:?dotfiles repo URL required}"

export TERM="${TERM:-xterm-256color}"

sh -c "$(download_to_stdout https://get.chezmoi.io)"
chmod 755 "$HOME/bin/chezmoi"
ls -l "$HOME/bin/chezmoi"
"$HOME/bin/chezmoi" --version
"$HOME/bin/chezmoi" init --apply "$DOTFILES_REPO"
