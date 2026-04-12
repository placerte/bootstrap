# Taskwarrior component

Taskwarrior is optional in the bootstrap flow.

## Current behavior

The bootstrap script can optionally build and install Taskwarrior from source.
This is intended for setups that need a newer Taskwarrior 3.x release than the distro package provides.

## Why source build here

For this setup, Taskwarrior 3+ matters because it is used together with TaskChampion-backed sync/service expectations.

## Scope

This repo only owns the optional installation/build step.
Task usage conventions, workflow, and personal task-management operating model belong elsewhere.

## Notes

- the bootstrap flow prompts before doing the Taskwarrior source build
- the source tarball is fetched from the upstream GitHub repository
- this step is intentionally optional because it adds build time and dependencies
