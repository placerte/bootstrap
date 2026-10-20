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
- the latest `yazi` release, installed directly from GitHub to `/usr/local/bin` when `yazi`/`ya` are not already present
- the latest `leaf` release, installed with its checksumming upstream installer to `~/.local/bin`
- Tailscale via the upstream install script

Implementation files:
- `scripts/30-cli-tools.sh`
- `scripts/install-yazi.sh`
