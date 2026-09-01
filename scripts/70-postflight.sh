#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

PLATFORM="${1:-debian}"
PROFILE="${2:-headless}"
WITH_CHEZMOI="${3:-false}"
WITH_PVETUI="${4:-false}"
APPLY_CHEZMOI="${5:-false}"

printf '%sSummary%s\n' "$C_BOLD" "$C_RESET"
printf '  platform     : %s\n' "$PLATFORM"
printf '  Profile      : %s\n' "$PROFILE"
printf '  chezmoi      : %s\n' "$WITH_CHEZMOI"
printf '  chezmoi apply: %s\n' "$APPLY_CHEZMOI"
printf '  pvetui       : %s\n' "$WITH_PVETUI"

echo
printf '%sRecommended next steps%s\n' "$C_BOLD" "$C_RESET"
if [[ "$PLATFORM" == "omarchy" ]]; then
  printf '  %s•%s Open a fresh Bash terminal to load shell changes\n' "$C_GREEN" "$C_RESET"
else
  printf '  %s•%s Start a fresh shell, for example: exec zsh\n' "$C_GREEN" "$C_RESET"
fi
printf '  %s•%s Verify: which nvim && nvim --version\n' "$C_GREEN" "$C_RESET"
printf '  %s•%s If using LazyVim, launch nvim once or twice\n' "$C_GREEN" "$C_RESET"

if [[ "$WITH_CHEZMOI" == "true" ]]; then
  printf '  %s•%s Apply when ready: chezmoi apply\n' "$C_GREEN" "$C_RESET"
  printf '  %s•%s Update later with: chezmoi update\n' "$C_GREEN" "$C_RESET"
fi

if [[ "$PLATFORM" == "debian" && "$PROFILE" == "gui" ]]; then
  printf '  %s•%s Consider a reboot after display manager and desktop setup changes\n' "$C_GREEN" "$C_RESET"
fi

if [[ "$WITH_PVETUI" == "true" ]]; then
  printf '  %s•%s Verify: pvetui --version\n' "$C_GREEN" "$C_RESET"
fi

echo
printf '%sThe machine should now be in a good first-boot state.%s\n' "$C_DIM" "$C_RESET"
