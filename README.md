# Debian Bootstrap

A public bootstrap repository for fresh Debian machines.

This repo is designed to be safe to publish and easy to audit:
- it installs packages and common terminal and desktop tools
- it supports both headless and GUI profiles
- it can optionally fix the hostname early, which is handy for Proxmox template clones
- it can optionally install and initialize `chezmoi`
- it keeps a simple bash-first, fresh-machine-friendly UX
- it does **not** contain private dotfiles or secrets

Your private configuration should stay in your separate `chezmoi` source repository.

## Quick start

Interactive mode:

```bash
wget -qO /tmp/bootstrap.sh https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh && bash /tmp/bootstrap.sh
```

If you prefer process substitution:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh)
```

Non-interactive examples:

```bash
wget -qO /tmp/bootstrap.sh https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh && bash /tmp/bootstrap.sh --profile headless --with-chezmoi --yes
```

```bash
wget -qO /tmp/bootstrap.sh https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh && bash /tmp/bootstrap.sh --profile gui --with-chezmoi --dotfiles-repo https://github.com/placerte/dotfiles.git --yes
```

## What it does

The top-level `bootstrap.sh` orchestrates a sequence of smaller scripts:

- `scripts/00-preflight.sh`
- `scripts/05-hostname.sh`
- `scripts/10-base-packages.sh`
- `scripts/20-shell.sh`
- `scripts/30-cli-tools.sh`
- `scripts/40-python.sh`
- `scripts/45-editors.sh`
- `scripts/50-gui.sh`
- `scripts/55-taskwarrior.sh`
- `scripts/56-pvetui.sh`
- `scripts/60-chezmoi.sh`
- `scripts/70-postflight.sh`

This keeps the public entrypoint simple while the implementation stays modular.

Short component notes live under:
- `docs/components/cli-tools.md`
- `docs/components/python.md`
- `docs/components/editors.md`
- `docs/components/gui.md`
- `docs/components/taskwarrior.md`
- `docs/components/pve.md`

## UX

The script is still plain bash so it stays compatible with an almost-empty machine, but it now aims to feel nicer than a pile of raw commands:

- a small interactive selection screen for `headless` vs `gui`
- clearer step banners
- lightweight colored progress output when the terminal supports it
- a readable end-of-run summary
- an early hostname-fix prompt for cloned VMs
- an optional Tailscale bring-up prompt after installation
- an optional Taskwarrior source-build prompt for Taskwarrior 3.x setups
- an optional `pvetui` install step for Proxmox-oriented machines

## Profiles

- `headless`: terminal-first setup
- `gui`: headless setup plus Xorg/i3 and related desktop tools

## Flags

- `--profile <headless|gui>`
- `--with-chezmoi`
- `--without-chezmoi`
- `--with-pvetui`
- `--without-pvetui`
- `--dotfiles-repo <git-url>`
- `--yes` to skip prompts where possible
- `--help`

## Notes

- Primary target: Debian 13
- The scripts are intended to be readable and mostly idempotent
- The launcher is designed for fresh machines where `wget` may exist before `curl` or `git`
- CLI tools include apt-installed basics plus a direct-install of the latest Yazi release to `/usr/local/bin`
- Tailscale installation is included, and interactive runs can optionally bring it up immediately
- Taskwarrior can be built from a pinned upstream Git tag as an optional step
- the optional Taskwarrior build currently installs Rust via rustup if the toolchain is missing
- `pvetui` can be installed as an optional pinned `.deb` download for Proxmox-focused hosts
- For first-run `chezmoi`, the scripts use the literal `$HOME/bin/chezmoi` path to avoid early PATH issues
- If running from a remote Kitty session on a very fresh machine, the script exports `TERM=xterm-256color` as a bootstrap guardrail
- Prefer SSH over noVNC for real bootstrap runs when possible
