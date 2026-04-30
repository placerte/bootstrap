#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

PROFILE="${1:-headless}"
WITH_CHEZMOI="${2:-false}"
WITH_PVETUI="${3:-false}"

printf '%sSummary%s\n' "$C_BOLD" "$C_RESET"
printf '  Profile      : %s\n' "$PROFILE"
printf '  chezmoi      : %s\n' "$WITH_CHEZMOI"
printf '  pvetui       : %s\n' "$WITH_PVETUI"

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

if [[ "$WITH_PVETUI" == "true" ]]; then
  printf '  %s•%s Verify: pvetui --version\n' "$C_GREEN" "$C_RESET"
fi

echo
printf '%sThe machine should now be in a good first-boot state.%s\n' "$C_DIM" "$C_RESET"
