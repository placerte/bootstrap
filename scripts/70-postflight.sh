#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-headless}"
WITH_CHEZMOI="${2:-false}"

echo
echo "Postflight summary"
echo "- Profile: $PROFILE"
echo "- chezmoi enabled: $WITH_CHEZMOI"
echo

echo "Recommended next steps:"
echo "- Start a fresh shell, for example: exec zsh"
echo "- Verify: which nvim && nvim --version"
echo "- If using LazyVim, launch nvim once or twice"

if [[ "$WITH_CHEZMOI" == "true" ]]; then
  echo "- Rerun if needed: \$HOME/bin/chezmoi apply"
  echo "- Update later with: \$HOME/bin/chezmoi update"
fi

if [[ "$PROFILE" == "gui" ]]; then
  echo "- Consider a reboot after display manager and desktop setup changes"
fi
