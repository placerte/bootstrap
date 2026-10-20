# Debian and Omarchy Bootstrap

A public bootstrap repository for fresh Debian and Omarchy machines.

This repo is designed to be safe to publish and easy to audit:
- it installs packages and common terminal and desktop tools
- it supports both headless and GUI profiles
- it supports a cherry-pick mode for running selected component scripts on demand
- it can optionally fix the hostname early, which is handy for Proxmox template clones
- it can optionally install and initialize `chezmoi`
- it keeps a simple bash-first, fresh-machine-friendly UX
- it does **not** contain private dotfiles or secrets

Your private configuration should stay in your separate `chezmoi` source repository.

## Quick start

Interactive mode:

```bash
curl -fsSL -o /tmp/bootstrap.sh https://github.com/placerte/bootstrap/raw/refs/heads/main/bootstrap.sh && bash /tmp/bootstrap.sh
```

Non-interactive examples:

```bash
wget -qO /tmp/bootstrap.sh https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh && bash /tmp/bootstrap.sh --profile headless --with-chezmoi --yes
```

```bash
wget -qO /tmp/bootstrap.sh https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh && bash /tmp/bootstrap.sh --profile gui --with-chezmoi --dotfiles-repo https://www.github.com/placerte/dotfiles --yes
```

```bash
wget -qO /tmp/bootstrap.sh https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh && bash /tmp/bootstrap.sh --profile cherry-pick --components editors --yes
```

Omarchy (the platform is normally auto-detected):

```bash
curl -fsSL -o /tmp/bootstrap.sh https://github.com/placerte/bootstrap/raw/refs/heads/main/bootstrap.sh && bash /tmp/bootstrap.sh --platform omarchy --yes
```

Preview the Omarchy plan without executing any component:

```bash
curl -fsSL -o /tmp/bootstrap.sh https://github.com/placerte/bootstrap/raw/refs/heads/main/bootstrap.sh && bash /tmp/bootstrap.sh --platform omarchy --yes --dry-run
```

## What it does

The top-level `bootstrap.sh` orchestrates a sequence of smaller scripts:

- `scripts/00-preflight.sh`
- `scripts/05-hostname.sh`
- `scripts/10-base-packages.sh`
- `scripts/10-omarchy-packages.sh`
- `scripts/15-keyboard.sh`
- `scripts/20-shell.sh`
- `scripts/30-cli-tools.sh`
- `scripts/30-omarchy-terminal.sh`
- `scripts/40-python.sh`
- `scripts/40-omarchy-tailscale.sh`
- `scripts/45-editors.sh`
- `scripts/50-gui.sh`
- `scripts/60-chezmoi.sh`
- `scripts/60-omarchy-chezmoi.sh`
- `scripts/70-postflight.sh`

This keeps the public entrypoint simple while the implementation stays modular.

Short component notes live under:
- `docs/components/cli-tools.md`
- `docs/components/python.md`
- `docs/components/editors.md`
- `docs/components/gui.md`
- `docs/components/omarchy.md`

## UX

The script is still plain bash so it stays compatible with an almost-empty machine, but it now aims to feel nicer than a pile of raw commands:

- a small interactive selection screen for `headless`, `gui`, or `cherry-pick`
- clearer step banners
- lightweight colored progress output when the terminal supports it
- a readable end-of-run summary
- an early hostname-fix prompt for cloned VMs
- an optional Tailscale bring-up prompt after installation
- a cherry-pick mode for running selected components like `editors` without a full bootstrap

## Profiles

- `headless`: terminal-first setup
- `gui`: headless setup plus Xorg/i3 and related desktop tools
- `cherry-pick`: choose one or more component scripts to run independently

The platform is detected independently from the profile. Debian is detected from
`ID=debian` and Omarchy from `ID=omarchy` in `/etc/os-release`. Use
`--platform debian` or `--platform omarchy` only when an explicit override is
needed. Omarchy defaults to the `gui` profile and does not accept `headless`.
The Omarchy package component uses `omarchy pkg` to add Yazi, ImageMagick,
`lsd`, Magic Wormhole, and npm. Leaf is installed to `~/.local/bin` with its
upstream checksumming installer.
Its shared shell component installs Zsh, Oh My Zsh, Powerlevel10k,
autosuggestions, and syntax highlighting on both platforms, and sets Zsh as the
default login shell. It removes bootstrap-managed `ble.sh` configuration and the
recognized pinned installation on both platforms; unrecognized installations
are retained with a warning. The terminal component selects Kitty through Omarchy and verifies
the theme include plus Yazi/ImageMagick preview support.
The keyboard component configures the Canadian Multilingual XKB layout (`ca`,
variant `multix`) in the user Hyprland input configuration on both platforms.

## Omarchy behavior

The Omarchy path retains the existing Hyprland session, Omarchy shell,
themes, and packaged configuration. It adds:

- Yazi and ImageMagick for terminal file browsing and image previews
- `lsd`, Leaf, Magic Wormhole, and npm
- Canadian Multilingual keyboard layout (`ca/multix`)
- Zsh with Oh My Zsh, Powerlevel10k, autosuggestions, and syntax highlighting
- Kitty as the default terminal through `omarchy install terminal kitty`
- Tailscale through the Omarchy package helper, with activation kept separate
- optional chezmoi setup when explicitly selected

`--yes` does not run `tailscale up` or apply chezmoi dotfiles on Omarchy. Use
`--tailscale-up` and `--apply-chezmoi` for those actions. Personal configuration remains owned by the
external chezmoi repository; it is not copied into this project.

## Flags

- `--platform <auto|debian|omarchy>` (default: `auto`)
- `--profile <headless|gui|cherry-pick>`
- `--components <comma-or-space-separated list>` for non-interactive cherry-pick runs
- `--with-chezmoi`
- `--without-chezmoi`
- `--apply-chezmoi` to explicitly initialize/apply dotfiles on Omarchy
- `--without-apply-chezmoi`
- `--dotfiles-repo <git-url>`
- `--yes` to skip prompts where possible
- `--tailscale-up` to explicitly run `tailscale up` on Omarchy
- `--dry-run` to print the selected component commands without executing them
- `--help`

## Testing

The test suite forces Debian and Omarchy behavior and mocks privileged/network
commands, so it does not install packages or change the host:

```bash
bash tests/run.sh
```

It covers platform detection, Debian headless/GUI plans, Omarchy fresh and
repeat states, incompatible cherry-picks, package presence, shell integration,
Kitty/Yazi readiness, Tailscale consent, optional chezmoi flows, and release
architecture selection.

## Omarchy recovery and removal

- Preview a rerun first with `--platform omarchy --yes --dry-run`.
- Switch away from Kitty with `omarchy default terminal foot` (or another
  supported terminal).
- Zsh customizations live under `~/.oh-my-zsh`; change the login shell with
  `chsh -s /usr/bin/bash` if you want to revert to Bash.
- Remove optional packages with `omarchy pkg drop <package>`; use
  `omarchy remove service tailscale` for the Omarchy-managed Tailscale service.
- chezmoi changes remain governed by the external dotfiles repository and
  chezmoi's own diff/apply workflows.

## Notes

- Supported targets: Debian 13, 64-bit Raspberry Pi OS on Raspberry Pi 3B+, and Omarchy 4
- The scripts are intended to be readable and mostly idempotent
- The launcher can fetch component scripts with either `curl` or `wget`; the Omarchy examples use its preinstalled `curl`
- CLI tools include apt-installed basics plus direct installs of the latest Yazi and Leaf releases
- Tailscale installation is included, and interactive runs can optionally bring it up immediately
- cherry-pick mode discovers selectable component scripts dynamically and accepts menu numbers, script prefixes, or names like `editors`
- For first-run `chezmoi`, the scripts use the literal `$HOME/bin/chezmoi` path to avoid early PATH issues
- If running from a remote Kitty session on a very fresh machine, the script exports `TERM=xterm-256color` as a bootstrap guardrail
- Prefer SSH over noVNC for real bootstrap runs when possible

## Raspberry Pi 3B+

Use the 64-bit Raspberry Pi OS Lite image. The bootstrap treats both Debian and
Raspbian OS identifiers as the Debian platform and selects ARM64 release assets
for Yazi and Neovim. The 32-bit Raspberry Pi OS image is not supported because
those upstream projects do not both publish compatible 32-bit ARM archives.

```bash
curl -fsSL -o /tmp/bootstrap.sh https://github.com/placerte/bootstrap/raw/refs/heads/main/bootstrap.sh && \
  bash /tmp/bootstrap.sh --profile headless --without-chezmoi --yes
```
