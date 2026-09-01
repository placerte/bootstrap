#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

omarchy_output="$(bash "$ROOT_DIR/bootstrap.sh" --platform omarchy --profile gui --without-chezmoi --without-pvetui --yes --dry-run)"

for component in \
  00-preflight.sh \
  10-omarchy-packages.sh \
  20-omarchy-shell.sh \
  30-omarchy-terminal.sh \
  40-omarchy-tailscale.sh \
  70-postflight.sh; do
  if [[ "$omarchy_output" != *"$component"* ]]; then
    printf 'not ok - Omarchy dry run omitted %s\n' "$component" >&2
    exit 1
  fi
done
echo "ok - Omarchy dry run prints its complete component command plan"

if [[ "$omarchy_output" == *"Installing missing"* || "$omarchy_output" == *"Installing pinned"* ]]; then
  echo "not ok - Omarchy dry run executed a component" >&2
  exit 1
fi
echo "ok - Omarchy dry run does not execute components"

debian_headless="$(bash "$ROOT_DIR/bootstrap.sh" --platform debian --profile headless --without-chezmoi --without-pvetui --yes --dry-run)"
if [[ "$debian_headless" == *"50-gui.sh"* || "$debian_headless" == *"omarchy-"* ]]; then
  echo "not ok - Debian headless dry run contains incompatible components" >&2
  exit 1
fi
for component in 10-base-packages.sh 20-shell.sh 30-cli-tools.sh 40-python.sh 45-editors.sh; do
  [[ "$debian_headless" == *"$component"* ]] || {
    printf 'not ok - Debian headless dry run omitted %s\n' "$component" >&2
    exit 1
  }
done
echo "ok - Debian headless dry run prints only its compatible plan"

debian_gui="$(bash "$ROOT_DIR/bootstrap.sh" --platform debian --profile gui --without-chezmoi --without-pvetui --yes --dry-run)"
if [[ "$debian_gui" != *"50-gui.sh"* ]]; then
  echo "not ok - Debian GUI dry run omitted its GUI component" >&2
  exit 1
fi
echo "ok - Debian GUI dry run includes its GUI component"
