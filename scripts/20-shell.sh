#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

PLATFORM="${1:-debian}"
BLESH_REF="63c23e99f1f7133ae57b79f87b16d1f68cd39884"
BLESH_PREFIX="${BLESH_PREFIX:-$HOME/.local}"
BLESH_INSTALL_DIR="$BLESH_PREFIX/share/blesh"
BASHRC_PATH="${BASHRC_PATH:-$HOME/.bashrc}"
BLERC_PATH="${BLERC_PATH:-$HOME/.blerc}"
ZSHRC_PATH="${ZSHRC_PATH:-$HOME/.zshrc}"

remove_managed_block() {
  local path="$1"
  local begin="$2"
  local end="$3"
  local tmp_file

  [[ -e "$path" ]] || return 0
  tmp_file="$(mktemp)"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skipping=1; next }
    $0 == end { skipping=0; next }
    !skipping { print }
  ' "$path" >"$tmp_file"
  chmod --reference="$path" "$tmp_file" 2>/dev/null || chmod 0644 "$tmp_file"
  mv "$tmp_file" "$path"
}

remove_bootstrap_blesh() {
  remove_managed_block "$BASHRC_PATH" \
    "# >>> bootstrap ble.sh load >>>" \
    "# <<< bootstrap ble.sh load <<<"
  remove_managed_block "$BASHRC_PATH" \
    "# >>> bootstrap ble.sh attach >>>" \
    "# <<< bootstrap ble.sh attach <<<"
  remove_managed_block "$BLERC_PATH" \
    "# >>> bootstrap Omarchy ANSI theme >>>" \
    "# <<< bootstrap Omarchy ANSI theme <<<"

  if [[ -d "$BLESH_INSTALL_DIR" ]]; then
    if [[ -r "$BLESH_INSTALL_DIR/.bootstrap-ref" ]] &&
      [[ "$(<"$BLESH_INSTALL_DIR/.bootstrap-ref")" == "$BLESH_REF" ]]; then
      rm -rf -- "$BLESH_INSTALL_DIR"
      success "Removed the bootstrap-managed ble.sh installation"
    else
      warn "Leaving unrecognized ble.sh installation in $BLESH_INSTALL_DIR"
    fi
  fi
}

case "$PLATFORM" in
  debian)
    sudo apt install -y zsh
    ;;
  omarchy)
    if ! command -v omarchy >/dev/null 2>&1; then
      fail "Installing zsh on Omarchy requires the omarchy command"
      exit 1
    fi
    if ! omarchy pkg present zsh; then
      omarchy pkg add zsh
    fi
    ;;
  *)
    fail "Unsupported shell platform: $PLATFORM"
    exit 1
    ;;
esac

configure_zshrc() {
  local tmp_file
  mkdir -p "$(dirname "$ZSHRC_PATH")"
  touch "$ZSHRC_PATH"
  tmp_file="$(mktemp)"

  awk '
    /^ZSH_THEME=/ {
      print "ZSH_THEME=\"powerlevel10k/powerlevel10k\""
      theme=1
      next
    }
    /^plugins=/ {
      print "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)"
      plugins=1
      next
    }
    { print }
    END {
      if (!theme) print "ZSH_THEME=\"powerlevel10k/powerlevel10k\""
      if (!plugins) print "plugins=(git zsh-autosuggestions zsh-syntax-highlighting)"
    }
  ' "$ZSHRC_PATH" >"$tmp_file"

  chmod --reference="$ZSHRC_PATH" "$tmp_file" 2>/dev/null || chmod 0644 "$tmp_file"
  mv "$tmp_file" "$ZSHRC_PATH"
}

remove_bootstrap_blesh

ZSH_PATH="$(command -v zsh)"

if [[ "${SHELL:-}" != "$ZSH_PATH" ]]; then
  echo "Setting default shell to $ZSH_PATH"
  if ! chsh -s "$ZSH_PATH"; then
    fail "Could not set the login shell to $ZSH_PATH; run 'chsh -s $ZSH_PATH' manually"
    exit 1
  fi
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no sh -c "$(download_to_stdout https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM_DIR/themes" "$ZSH_CUSTOM_DIR/plugins"

if [[ ! -d "$ZSH_CUSTOM_DIR/themes/powerlevel10k" ]]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
fi

if [[ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
fi

if [[ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
fi

configure_zshrc
success "Zsh and plugins are installed"
