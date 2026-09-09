#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mock_bin="$tmp_dir/bin"
mkdir -p "$mock_bin"

cat >"$mock_bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"$SHELL_TEST_LOG"
EOF

cat >"$mock_bin/omarchy" <<'EOF'
#!/usr/bin/env bash
printf 'omarchy %s\n' "$*" >>"$SHELL_TEST_LOG"
[[ "$*" != "pkg present zsh" ]]
EOF

cat >"$mock_bin/chsh" <<'EOF'
#!/usr/bin/env bash
printf 'chsh %s\n' "$*" >>"$SHELL_TEST_LOG"
EOF

cat >"$mock_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\n' "$*" >>"$SHELL_TEST_LOG"
mkdir -p "${@: -1}"
EOF

cat >"$mock_bin/zsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$mock_bin/zsh"

chmod +x "$mock_bin/sudo" "$mock_bin/omarchy" "$mock_bin/chsh" "$mock_bin/git"

run_shell_test() {
  local platform="$1"
  local test_home="$tmp_dir/$platform-home"
  local log_file="$tmp_dir/$platform.log"
  mkdir -p "$test_home/.oh-my-zsh" "$test_home/.local/share/blesh"
  printf '63c23e99f1f7133ae57b79f87b16d1f68cd39884\n' >"$test_home/.local/share/blesh/.bootstrap-ref"
  cat >"$test_home/.bashrc" <<'EOF'
keep-bash-setting
# >>> bootstrap ble.sh load >>>
source unwanted-ble
# <<< bootstrap ble.sh load <<<
EOF
  cat >"$test_home/.blerc" <<'EOF'
keep-ble-setting
# >>> bootstrap Omarchy ANSI theme >>>
ble-face unwanted
# <<< bootstrap Omarchy ANSI theme <<<
EOF
  cat >"$test_home/.zshrc" <<'EOF'
ZSH_THEME="robbyrussell"
plugins=(git)
keep-zsh-setting
EOF

  HOME="$test_home" SHELL=/usr/bin/bash ZSHRC_PATH="$test_home/.zshrc" \
    SHELL_TEST_LOG="$log_file" PATH="$mock_bin:$PATH" \
    bash "$ROOT_DIR/scripts/20-shell.sh" "$platform" >/dev/null

  if [[ "$platform" == "debian" ]]; then
    rg -qx 'sudo apt install -y zsh' "$log_file"
  else
    rg -qx 'omarchy pkg add zsh' "$log_file"
  fi
  rg -Fxq "chsh -s $mock_bin/zsh" "$log_file"
  rg -qx 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$test_home/.zshrc"
  rg -qx 'plugins=\(git zsh-autosuggestions zsh-syntax-highlighting\)' "$test_home/.zshrc"
  rg -qx 'keep-zsh-setting' "$test_home/.zshrc"
  rg -qx 'keep-bash-setting' "$test_home/.bashrc"
  rg -qx 'keep-ble-setting' "$test_home/.blerc"
  ! rg -q 'bootstrap ble|unwanted' "$test_home/.bashrc" "$test_home/.blerc"
  [[ ! -e "$test_home/.local/share/blesh" ]]
}

run_shell_test debian
echo "ok - Debian installs and configures Zsh plugins"
run_shell_test omarchy
echo "ok - Omarchy installs and configures Zsh plugins and removes managed ble.sh"
