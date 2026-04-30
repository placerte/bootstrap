# Proxmox / pvetui component

`pvetui` is optional in the bootstrap flow.

## Current behavior

The bootstrap script can optionally install a pinned `pvetui` release from the upstream GitHub `.deb` artifact.

## Why this lives here

For Proxmox-oriented hosts, `pvetui` is part of the operator toolbelt rather than a general Debian base package.
Keeping it optional avoids imposing a Proxmox-specific dependency on every machine.

## Current pin

- version: `1.3.2`
- artifact: `pvetui_1.3.2_linux_amd64.deb`

## Notes

- this step is intentionally optional because most Debian machines do not need Proxmox tooling
- the current installer path targets `amd64` only
- the package is fetched directly from the upstream GitHub release rather than the distro package manager