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
- `tree`
- `tealdeer`
- the latest `yazi` release, installed directly from GitHub to `/usr/local/bin` when `yazi`/`ya` are not already present
- Tailscale via the upstream install script

Implementation files:
- `scripts/30-cli-tools.sh`
- `scripts/install-yazi.sh`
