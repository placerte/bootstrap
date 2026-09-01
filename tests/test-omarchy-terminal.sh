#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mock_bin="$tmp_dir/bin"
test_home="$tmp_dir/home"
preference="$test_home/.config/xdg-terminals.list"
kitty_config="$test_home/.config/kitty/kitty.conf"
log_file="$tmp_dir/omarchy.log"
mkdir -p "$mock_bin" "$test_home/.config"

for command_name in yazi ya magick; do
  cat >"$mock_bin/$command_name" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$mock_bin/$command_name"
done

cat >"$mock_bin/kitty" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "+kitten icat --help" ]]
EOF
chmod +x "$mock_bin/kitty"

cat >"$mock_bin/omarchy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$OMARCHY_TERMINAL_TEST_LOG"
[[ "$*" == "install terminal kitty" ]]
mkdir -p "$(dirname "$TERMINAL_PREFERENCE")" "$(dirname "$KITTY_CONFIG")"
printf '# preference\nkitty.desktop\n' >"$TERMINAL_PREFERENCE"
printf 'include ~/.local/state/omarchy/current/theme/kitty.conf\nfont_size 11\n' >"$KITTY_CONFIG"
EOF
chmod +x "$mock_bin/omarchy"

run_component() {
  HOME="$test_home" \
  TERMINAL_PREFERENCE="$preference" \
  KITTY_CONFIG="$kitty_config" \
  OMARCHY_TERMINAL_TEST_LOG="$log_file" \
  PATH="$mock_bin:$PATH" \
    bash "$ROOT_DIR/scripts/30-omarchy-terminal.sh" >/dev/null
}

run_component
if [[ "$(cat "$log_file")" != "install terminal kitty" ]]; then
  echo "not ok - incomplete terminal state did not use the Omarchy installer" >&2
  exit 1
fi
echo "ok - incomplete state uses the supported Omarchy installer"

first_log="$(cat "$log_file")"
run_component
if [[ "$(cat "$log_file")" != "$first_log" ]]; then
  echo "not ok - completed terminal state reran the installer" >&2
  exit 1
fi
echo "ok - completed terminal state is a no-op"

if [[ "$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$preference" | head -n 1)" != "kitty.desktop" ]]; then
  echo "not ok - Kitty is not the first terminal preference" >&2
  exit 1
fi
echo "ok - Kitty is the default terminal"

grep -Fqx 'include ~/.local/state/omarchy/current/theme/kitty.conf' "$kitty_config"
grep -Fqx 'font_size 11' "$kitty_config"
echo "ok - Omarchy theme include and existing config content are preserved"

if YAZI_PREVIEW_COMMANDS="yazi ya definitely-missing-preview-command" run_component 2>"$tmp_dir/missing.err"; then
  echo "not ok - missing image preview dependency was accepted" >&2
  exit 1
fi
grep -q 'Yazi preview requirement is missing: definitely-missing-preview-command' "$tmp_dir/missing.err"
echo "ok - missing preview dependencies fail clearly"
