# Editors component

The bootstrap flow installs the editor baseline for this setup.

## Current behavior

- installs upstream Neovim from the official release tarball
- installs `sc-im` from Debian packages

## Scope

This repo owns provisioning of editor binaries.

Editor-specific configuration, LazyVim behavior, conventions, and deeper setup notes belong in the separate `dotfiles` / `chezmoi` repository.

## Notes

- upstream Neovim is preferred here because Debian 13's packaged version may lag current LazyVim expectations
- after bootstrap, launch `nvim` once or twice to finish first-run setup if applicable
