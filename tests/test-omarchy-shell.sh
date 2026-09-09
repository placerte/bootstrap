#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

test_home="$tmp_dir/home"
mock_bin="$tmp_dir/bin"
state_file="$tmp_dir/zsh-installed"
log_file="$tmp_dir/commands.log"
mkdir -p \
  "$test_home/.local/share/blesh" \
  "$test_home/.oh-my-zsh/custom/themes/powerlevel10k" \
  "$test_home/.oh-my-zsh/custom/plugins/zsh-autosuggestions" \
  "$test_home/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" \
  "$mock_bin"

cat >"$mock_bin/omarchy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'omarchy %s\n' "$*" >>"$SHELL_TEST_LOG"
if [[ "$*" == "pkg present zsh" ]]; then
  [[ -e "$SHELL_TEST_STATE" ]]
elif [[ "$*" == "pkg add zsh" ]]; then
  touch "$SHELL_TEST_STATE"
fi
EOF

cat >"$mock_bin/chsh" <<'EOF'
#!/usr/bin/env bash
printf 'chsh %s\n' "$*" >>"$SHELL_TEST_LOG"
EOF

cat >"$mock_bin/zsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$mock_bin/omarchy" "$mock_bin/chsh" "$mock_bin/zsh"

cat >"$test_home/.bashrc" <<'EOF'
alias personal-alias='printf preserved'
# >>> bootstrap ble.sh load >>>
source "$HOME/.local/share/blesh/ble.sh" --attach=none
# <<< bootstrap ble.sh load <<<
# >>> bootstrap ble.sh attach >>>
ble-attach
# <<< bootstrap ble.sh attach <<<
EOF

cat >"$test_home/.blerc" <<'EOF'
# personal ble setting
# >>> bootstrap Omarchy ANSI theme >>>
ble-face syntax_command='fg=blue'
# <<< bootstrap Omarchy ANSI theme <<<
EOF
printf '%s\n' '63c23e99f1f7133ae57b79f87b16d1f68cd39884' \
  >"$test_home/.local/share/blesh/.bootstrap-ref"

run_component() {
  HOME="$test_home" \
  SHELL="/bin/bash" \
  BLESH_PREFIX="$test_home/.local" \
  BASHRC_PATH="$test_home/.bashrc" \
  BLERC_PATH="$test_home/.blerc" \
  SHELL_TEST_LOG="$log_file" \
  SHELL_TEST_STATE="$state_file" \
  PATH="$mock_bin:$PATH" \
    bash "$ROOT_DIR/scripts/20-shell.sh" omarchy
}

run_component >/dev/null
run_component >/dev/null

[[ "$(rg -c '^omarchy pkg add zsh$' "$log_file")" == "1" ]]
echo "ok - Omarchy installs zsh through its package helper idempotently"

if rg -q 'bootstrap ble.sh|bootstrap Omarchy ANSI theme' \
  "$test_home/.bashrc" "$test_home/.blerc"; then
  echo "not ok - managed ble.sh configuration remains" >&2
  exit 1
fi
[[ ! -e "$test_home/.local/share/blesh" ]]
echo "ok - bootstrap-managed ble.sh state is removed idempotently"

rg -q "alias personal-alias='printf preserved'" "$test_home/.bashrc"
rg -q '# personal ble setting' "$test_home/.blerc"
echo "ok - unrelated Bash and blerc content is preserved"

expected_zsh="$mock_bin/zsh"
rg -q "^chsh -s $expected_zsh$" "$log_file"
echo "ok - the resolved zsh executable becomes the login shell"

mkdir -p "$test_home/.local/share/blesh"
printf '%s\n' manual-install >"$test_home/.local/share/blesh/ble.sh"
warning="$(run_component 2>&1)"
[[ -e "$test_home/.local/share/blesh/ble.sh" ]]
[[ "$warning" == *"Leaving unrecognized ble.sh installation"* ]]
echo "ok - unrecognized ble.sh installations are retained with a warning"
