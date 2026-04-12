# Python component

The bootstrap flow installs the base Python tooling for this setup:

- `python3`
- `python3-venv`
- `python3-tk`
- `python3-pip`
- `uv`

## Scope

This bootstrap repo only owns provisioning of the Python toolchain.

Preferred workflow, conventions, and longer-lived setup opinions belong in the separate `dotfiles` / `chezmoi` repository.

## Notes

- Debian 13 provides the system Python base
- `uv` is the preferred Python workflow tool in this setup
- If you need the deeper workflow notes, see the corresponding Python documentation in the dotfiles repo
