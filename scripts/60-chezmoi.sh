#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO="${1:?dotfiles repo URL required}"

export TERM="${TERM:-xterm-256color}"

sh -c "$(wget -qO- get.chezmoi.io)"
chmod 755 "$HOME/bin/chezmoi"
ls -l "$HOME/bin/chezmoi"
"$HOME/bin/chezmoi" --version
"$HOME/bin/chezmoi" init --apply --exclude=.config/nvim/lazy-lock.json "$DOTFILES_REPO"
