#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

test_home="$tmp_dir/home"
mock_bin="$tmp_dir/bin"
mkdir -p "$test_home" "$mock_bin"

cat >"$mock_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\n' "$*" >>"$OMARCHY_SHELL_TEST_LOG"
EOF

cat >"$mock_bin/make" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'make %s\n' "$*" >>"$OMARCHY_SHELL_TEST_LOG"
for arg in "$@"; do
  case "$arg" in
    PREFIX=*) prefix="${arg#PREFIX=}" ;;
  esac
done
mkdir -p "$prefix/share/blesh"
printf '# test ble.sh\n' >"$prefix/share/blesh/ble.sh"
EOF

cat >"$mock_bin/gawk" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$mock_bin/git" "$mock_bin/make" "$mock_bin/gawk"

cat >"$test_home/.bashrc" <<'EOF'
# Omarchy environment
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap
[[ $- != *i* ]] && return
source "$OMARCHY_PATH/default/bash/rc"
alias personal-alias='printf preserved'
EOF

printf '%s\n' "# personal ble setting" >"$test_home/.blerc"
log_file="$tmp_dir/install.log"

run_component() {
  HOME="$test_home" \
  BLESH_PREFIX="$test_home/.local" \
  BASHRC_PATH="$test_home/.bashrc" \
  BLERC_PATH="$test_home/.blerc" \
  OMARCHY_SHELL_TEST_LOG="$log_file" \
  PATH="$mock_bin:$PATH" \
    bash "$ROOT_DIR/scripts/20-omarchy-shell.sh" >/dev/null
}

run_component
first_log="$(cat "$log_file")"
run_component
second_log="$(cat "$log_file")"

if [[ "$first_log" != "$second_log" ]]; then
  echo "not ok - rerun attempted to reinstall the pinned ble.sh revision" >&2
  exit 1
fi
echo "ok - pinned ble.sh install is idempotent"

for marker in \
  "bootstrap ble.sh load" \
  "bootstrap ble.sh attach" \
  "bootstrap Omarchy ANSI theme"; do
  count="$(rg -c ">>> $marker >>>" "$test_home/.bashrc" "$test_home/.blerc" | awk -F: '{sum += $NF} END {print sum}')"
  if [[ "$count" != "1" ]]; then
    printf 'not ok - expected one managed %s block, found %s\n' "$marker" "$count" >&2
    exit 1
  fi
done
echo "ok - rerun does not duplicate managed blocks"

rg -q "alias personal-alias='printf preserved'" "$test_home/.bashrc"
rg -q "# personal ble setting" "$test_home/.blerc"
echo "ok - unrelated Bash and ble.sh settings are preserved"

load_line="$(rg -n '>>> bootstrap ble.sh load >>>' "$test_home/.bashrc" | cut -d: -f1)"
omarchy_line="$(rg -n 'source \"\$OMARCHY_PATH/default/bash/rc\"' "$test_home/.bashrc" | cut -d: -f1)"
attach_line="$(rg -n '>>> bootstrap ble.sh attach >>>' "$test_home/.bashrc" | cut -d: -f1)"

if ! ((load_line < omarchy_line && omarchy_line < attach_line)); then
  echo "not ok - ble.sh load/attach does not surround Omarchy Bash initialization" >&2
  exit 1
fi
echo "ok - ble.sh load and attach surround Omarchy initialization"

noninteractive="$(HOME="$test_home" BASH_ENV="$test_home/.bashrc" bash -c 'printf "%s" "${BLE_VERSION:-missing}"')"
if [[ "$noninteractive" != "missing" ]]; then
  echo "not ok - ble.sh loaded in a non-interactive Bash session" >&2
  exit 1
fi
echo "ok - non-interactive Bash remains unaffected"

rg -q "ble-face auto_complete='fg=gray,italic'" "$test_home/.blerc"
if rg -n 'fg=[0-9]' "$test_home/.blerc"; then
  echo "not ok - ble.sh theme uses fixed indexed colors" >&2
  exit 1
fi
echo "ok - ble.sh faces use Omarchy-compatible ANSI colors"
