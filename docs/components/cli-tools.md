# CLI tools

The CLI tools step installs a small terminal-first toolkit for both `headless` and `gui` profiles.

It currently includes:
- `btop`
- `fastfetch`
- `lsd`
- `fzf`
- `zip`
- `unzip`
- `glow`
- `magic-wormhole`
- `tree`
- `tealdeer`
- `tmux`
- the latest `yazi` release, installed directly from GitHub to `/usr/local/bin` when `yazi`/`ya` are not already present
- the latest `leaf` release, installed with its checksumming upstream installer to `~/.local/bin`
- Tailscale via the upstream install script

Implementation files:
- `scripts/30-cli-tools.sh`
- `scripts/install-yazi.sh`

Debian also installs Node.js 24 from NodeSource in `scripts/12-nodejs.sh`, so
modern npm/npx applications do not depend on Debian's older Node.js package.

Codex CLI and Hermes Agent are optional components. Interactive full-profile
runs offer both choices; unattended runs use `--with-codex` and/or
`--with-hermes`. Add `--ai-login` to explicitly start device-code authentication,
or authenticate later with `codex login --device-auth` and
`hermes auth add openai-codex`.
