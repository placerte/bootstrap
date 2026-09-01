#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/home"
cat >"$tmp_dir/bin/localectl" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == status ]]; then
  [[ -r "${LOCALectl_STATUS_FILE:?}" ]] && cat "$LOCALectl_STATUS_FILE"
  exit 0
fi
if [[ "$1" == list-keymaps ]]; then
  printf 'us\nca-multix-1\n'
fi
printf '%s\n' "$*" >>"${LOCALectl_LOG:?}"
EOF
cat >"$tmp_dir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
chmod +x "$tmp_dir/bin/localectl" "$tmp_dir/bin/sudo"

status_file="$tmp_dir/localectl.status"
log_file="$tmp_dir/localectl.log"
printf 'X11 Layout: us\nX11 Variant: \n' >"$status_file"
: >"$log_file"
PATH="$tmp_dir/bin:$PATH" LOCALectl_STATUS_FILE="$status_file" LOCALectl_LOG="$log_file" \
  HOME="$tmp_dir/home" bash "$ROOT_DIR/scripts/15-keyboard.sh" debian >/dev/null
rg -q 'set-x11-keymap ca pc105 multix' "$log_file"
rg -q 'set-keymap ca-multix-1' "$log_file"
echo "ok - Debian keyboard setup uses localectl for X11 and console"

HYPR_DIR="$tmp_dir/home/.config/hypr" HOME="$tmp_dir/home" \
  bash "$ROOT_DIR/scripts/15-keyboard.sh" omarchy >/dev/null
HYPR_DIR="$tmp_dir/home/.config/hypr" HOME="$tmp_dir/home" \
  bash "$ROOT_DIR/scripts/15-keyboard.sh" omarchy >/dev/null
[[ "$(rg -c 'bootstrap Canadian Multilingual keyboard' "$tmp_dir/home/.config/hypr/input.lua")" -eq 2 ]]
echo "ok - Omarchy keyboard setup is persistent and idempotent"
