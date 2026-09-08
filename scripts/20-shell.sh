#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

PLATFORM="${1:-debian}"
ZSHRC_PATH="${ZSHRC_PATH:-$HOME/.zshrc}"

case "$PLATFORM" in
  debian) sudo apt install -y zsh ;;
  omarchy) omarchy pkg add zsh ;;
  *)
    fail "Unsupported platform for shell setup: $PLATFORM"
    exit 1
    ;;
esac

remove_legacy_blesh() {
  local file tmp_file

  for file in "$HOME/.bashrc" "$HOME/.blerc"; do
    [[ -f "$file" ]] || continue
    tmp_file="$(mktemp)"
    awk '
      $0 == "# >>> bootstrap ble.sh load >>>" ||
      $0 == "# >>> bootstrap ble.sh attach >>>" ||
      $0 == "# >>> bootstrap Omarchy ANSI theme >>>" { skipping=1; next }
      $0 == "# <<< bootstrap ble.sh load <<<" ||
      $0 == "# <<< bootstrap ble.sh attach <<<" ||
      $0 == "# <<< bootstrap Omarchy ANSI theme <<<" { skipping=0; next }
      !skipping { print }
    ' "$file" >"$tmp_file"
    chmod --reference="$file" "$tmp_file" 2>/dev/null || chmod 0644 "$tmp_file"
    mv "$tmp_file" "$file"
  done

  if [[ -f "$HOME/.local/share/blesh/.bootstrap-ref" ]]; then
    rm -rf "$HOME/.local/share/blesh"
  fi
}

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

remove_legacy_blesh

if [[ "${SHELL:-}" != "/usr/bin/zsh" ]]; then
  echo "Setting default shell to /usr/bin/zsh"
  chsh -s /usr/bin/zsh || true
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
