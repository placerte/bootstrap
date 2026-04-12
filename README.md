# Debian Bootstrap

A public bootstrap repository for fresh Debian machines.

This repo is designed to be safe to publish and easy to audit:
- it installs packages and common terminal and desktop tools
- it supports both headless and GUI profiles
- it can optionally install and initialize `chezmoi`
- it keeps a simple bash-first, fresh-machine-friendly UX
- it does **not** contain private dotfiles or secrets

Your private configuration should stay in your separate `chezmoi` source repository.

## Quick start

Interactive mode:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh)
```

If process substitution is awkward in your environment, use:

```bash
wget -qO /tmp/bootstrap.sh https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh && bash /tmp/bootstrap.sh
```

Non-interactive examples:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh) --profile headless --with-chezmoi --yes
```

```bash
bash <(wget -qO- https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh) --profile gui --with-chezmoi --dotfiles-repo https://github.com/placerte/dotfiles.git --yes
```

## What it does

The top-level `bootstrap.sh` orchestrates a sequence of smaller scripts:

- `scripts/00-preflight.sh`
- `scripts/10-base-packages.sh`
- `scripts/20-shell.sh`
- `scripts/30-cli-tools.sh`
- `scripts/40-python.sh`
- `scripts/45-editors.sh`
- `scripts/50-gui.sh`
- `scripts/60-chezmoi.sh`
- `scripts/70-postflight.sh`

This keeps the public entrypoint simple while the implementation stays modular.

## UX

The script is still plain bash so it stays compatible with an almost-empty machine, but it now aims to feel nicer than a pile of raw commands:

- a small interactive selection screen for `headless` vs `gui`
- clearer step banners
- lightweight colored progress output when the terminal supports it
- a readable end-of-run summary

## Profiles

- `headless`: terminal-first setup
- `gui`: headless setup plus Xorg/i3 and related desktop tools

## Flags

- `--profile <headless|gui>`
- `--with-chezmoi`
- `--dotfiles-repo <git-url>`
- `--yes` to skip prompts where possible
- `--help`

## Notes

- Primary target: Debian 13
- The scripts are intended to be readable and mostly idempotent
- For first-run `chezmoi`, the scripts use the literal `$HOME/bin/chezmoi` path to avoid early PATH issues
- If running from a remote Kitty session on a very fresh machine, the script exports `TERM=xterm-256color` as a bootstrap guardrail
