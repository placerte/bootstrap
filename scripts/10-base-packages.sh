#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y \
  build-essential \
  git \
  wget \
  curl \
  bison \
  magic-wormhole \
  tmux \
  snapd \
  ca-certificates
