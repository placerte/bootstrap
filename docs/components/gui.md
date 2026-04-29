# GUI component

The `gui` bootstrap profile installs the base desktop/session packages for this setup.

## Current behavior

The GUI profile adds packages such as:
- Xorg
- i3
- i3lock / i3lock-color
- picom
- sddm
- polybar
- kitty
- feh
- rofi
- keynav
- lxappearance
- arc-theme
- papirus-icon-theme

## Scope

This repo owns package provisioning for the GUI baseline.

The separate `dotfiles` / `chezmoi` repository owns the actual GUI configuration, appearance, theme/session details, and post-bootstrap adjustments.

## Notes

- prefer the `gui` profile only on machines that actually need the desktop stack
- GUI config behavior and theme details should stay documented with the managed config, not duplicated here
