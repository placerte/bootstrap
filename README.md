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

```bash
wget -qO /tmp/bootstrap.sh https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh && bash /tmp/bootstrap.sh --profile cherry-pick --components pvetui --yes
```

Omarchy (the platform is normally auto-detected):

```bash
wget -qO /tmp/bootstrap.sh https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh && bash /tmp/bootstrap.sh --platform omarchy --yes
```

Preview the Omarchy plan without executing any component:

```bash
wget -qO /tmp/bootstrap.sh https://raw.githubusercontent.com/placerte/bootstrap/main/bootstrap.sh && bash /tmp/bootstrap.sh --platform omarchy --yes --dry-run
```

## What it does

The top-level `bootstrap.sh` orchestrates a sequence of smaller scripts:

- `scripts/00-preflight.sh`
- `scripts/05-hostname.sh`
- `scripts/10-base-packages.sh`
- `scripts/10-omarchy-packages.sh`
- `scripts/20-shell.sh`
- `scripts/20-omarchy-shell.sh`
- `scripts/30-cli-tools.sh`
- `scripts/30-omarchy-terminal.sh`
- `scripts/40-python.sh`
- `scripts/40-omarchy-tailscale.sh`
- `scripts/45-editors.sh`
- `scripts/50-gui.sh`
- `scripts/56-pvetui.sh`
- `scripts/56-omarchy-pvetui.sh`
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
- `docs/components/pve.md`

## UX

The script is still plain bash so it stays compatible with an almost-empty machine, but it now aims to feel nicer than a pile of raw commands:

- a small interactive selection screen for `headless`, `gui`, or `cherry-pick`
- clearer step banners
- lightweight colored progress output when the terminal supports it
- a readable end-of-run summary
- an early hostname-fix prompt for cloned VMs
- an optional Tailscale bring-up prompt after installation
- an optional `pvetui` install step for Proxmox-oriented machines
- a cherry-pick mode for running selected components like `pvetui` without a full bootstrap

## Profiles

- `headless`: terminal-first setup
- `gui`: headless setup plus Xorg/i3 and related desktop tools
- `cherry-pick`: choose one or more component scripts to run independently

The platform is detected independently from the profile. Debian is detected from
`ID=debian` and Omarchy from `ID=omarchy` in `/etc/os-release`. Use
`--platform debian` or `--platform omarchy` only when an explicit override is
needed. Omarchy defaults to the `gui` profile and does not accept `headless`.
The Omarchy package component uses `omarchy pkg` and currently adds Yazi, the
only official-repository package explicitly selected in the reviewed inventory.
Its shell component preserves Bash and Omarchy's Starship setup, then installs a
pinned `ble.sh` revision with ANSI-based highlighting that follows terminal
theme changes. The terminal component selects Kitty through Omarchy and verifies
the theme include plus Yazi/ImageMagick preview support.

## Omarchy behavior

The Omarchy path retains the existing Hyprland session, Omarchy shell and
themes, Bash login shell, Starship prompt, and packaged configuration. It adds:

- Yazi and ImageMagick for terminal file browsing and image previews
- a pinned user-local `ble.sh` with theme-aware Bash highlighting/suggestions
- Kitty as the default terminal through `omarchy install terminal kitty`
- Tailscale through the Omarchy package helper, with activation kept separate
- optional chezmoi and pvetui components when explicitly selected

`--yes` does not run `tailscale up`, apply chezmoi dotfiles, or select optional
pvetui on Omarchy. Use `--tailscale-up`, `--apply-chezmoi`, and
`--with-pvetui` for those actions. Personal configuration remains owned by the
external chezmoi repository; it is not copied into this project.

## Flags

- `--platform <auto|debian|omarchy>` (default: `auto`)
- `--profile <headless|gui|cherry-pick>`
- `--components <comma-or-space-separated list>` for non-interactive cherry-pick runs
- `--with-chezmoi`
- `--without-chezmoi`
- `--apply-chezmoi` to explicitly initialize/apply dotfiles on Omarchy
- `--without-apply-chezmoi`
- `--with-pvetui`
- `--without-pvetui`
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
Kitty/Yazi readiness, Tailscale consent, and optional chezmoi/pvetui flows.

## Omarchy recovery and removal

- Preview a rerun first with `--platform omarchy --yes --dry-run`.
- Switch away from Kitty with `omarchy default terminal foot` (or another
  supported terminal).
- Remove bootstrap-managed `ble.sh` blocks from `~/.bashrc` and `~/.blerc`, then
  remove `~/.local/share/blesh` if the enhancement is no longer wanted.
- Remove optional packages with `omarchy pkg drop <package>`; use
  `omarchy remove service tailscale` for the Omarchy-managed Tailscale service.
- chezmoi changes remain governed by the external dotfiles repository and
  chezmoi's own diff/apply workflows.

## Notes

- Supported targets: Debian 13 and Omarchy 4
- The scripts are intended to be readable and mostly idempotent
- The launcher is designed for fresh machines where `wget` may exist before `curl` or `git`
- CLI tools include apt-installed basics plus a direct-install of the latest Yazi release to `/usr/local/bin`
- Tailscale installation is included, and interactive runs can optionally bring it up immediately
- `pvetui` can be installed as an optional pinned `.deb` download for Proxmox-focused hosts
- cherry-pick mode discovers selectable component scripts dynamically and accepts menu numbers, script prefixes, or names like `pvetui`
- For first-run `chezmoi`, the scripts use the literal `$HOME/bin/chezmoi` path to avoid early PATH issues
- If running from a remote Kitty session on a very fresh machine, the script exports `TERM=xterm-256color` as a bootstrap guardrail
- Prefer SSH over noVNC for real bootstrap runs when possible
