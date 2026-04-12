#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-headless}"
WITH_CHEZMOI="${2:-false}"

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_GREEN=$'\033[32m'
else
  C_RESET=""
  C_BOLD=""
  C_DIM=""
  C_GREEN=""
fi

printf '%sSummary%s\n' "$C_BOLD" "$C_RESET"
printf '  Profile      : %s\n' "$PROFILE"
printf '  chezmoi      : %s\n' "$WITH_CHEZMOI"

echo
printf '%sRecommended next steps%s\n' "$C_BOLD" "$C_RESET"
printf '  %s•%s Start a fresh shell, for example: exec zsh\n' "$C_GREEN" "$C_RESET"
printf '  %s•%s Verify: which nvim && nvim --version\n' "$C_GREEN" "$C_RESET"
printf '  %s•%s If using LazyVim, launch nvim once or twice\n' "$C_GREEN" "$C_RESET"

if [[ "$WITH_CHEZMOI" == "true" ]]; then
  printf '  %s•%s Rerun if needed: \$HOME/bin/chezmoi apply\n' "$C_GREEN" "$C_RESET"
  printf '  %s•%s Update later with: \$HOME/bin/chezmoi update\n' "$C_GREEN" "$C_RESET"
fi

if [[ "$PROFILE" == "gui" ]]; then
  printf '  %s•%s Consider a reboot after display manager and desktop setup changes\n' "$C_GREEN" "$C_RESET"
fi

echo
printf '%sThe machine should now be in a good first-boot state.%s\n' "$C_DIM" "$C_RESET"
