#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rg -q '^[[:space:]]+tmux \\' "$ROOT_DIR/scripts/10-base-packages.sh"
rg -q '^[[:space:]]+tmux$' "$ROOT_DIR/scripts/10-omarchy-packages.sh"
echo "ok - tmux is installed by default on Debian and Omarchy"

rg -q '^NODE_MAJOR=24$' "$ROOT_DIR/scripts/12-nodejs.sh"
rg -q 'deb\.nodesource\.com/setup_\$\{NODE_MAJOR\}\.x' "$ROOT_DIR/scripts/12-nodejs.sh"
rg -q 'sudo apt install -y nodejs' "$ROOT_DIR/scripts/12-nodejs.sh"
echo "ok - Debian Node.js uses the current NodeSource LTS channel"

rg -q 'npm install -g @openai/codex@latest' "$ROOT_DIR/scripts/55-codex.sh"
rg -q 'codex login --device-auth' "$ROOT_DIR/scripts/55-codex.sh"
rg -q 'hermes-agent\.nousresearch\.com/install\.sh' "$ROOT_DIR/scripts/56-hermes.sh"
rg -q 'hermes auth add openai-codex' "$ROOT_DIR/scripts/56-hermes.sh"
echo "ok - optional AI tools use their upstream installers and OpenAI device-code flows"
