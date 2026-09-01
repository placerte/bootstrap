#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"

cat >"$tmp_dir/bin/omarchy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$OMARCHY_TEST_LOG"

case "$1 $2" in
  "pkg present") [[ "$OMARCHY_TEST_STATE" == "present" ]] ;;
  "pkg add") exit 0 ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$tmp_dir/bin/omarchy"

run_case() {
  local state="$1"
  local expected="$2"
  local log_file="$tmp_dir/$state.log"

  OMARCHY_TEST_STATE="$state" \
  OMARCHY_TEST_LOG="$log_file" \
  PATH="$tmp_dir/bin:$PATH" \
    bash "$ROOT_DIR/scripts/10-omarchy-packages.sh" >/dev/null

  local actual
  actual="$(cat "$log_file")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'not ok - %s package case\nexpected:\n%s\nactual:\n%s\n' "$state" "$expected" "$actual" >&2
    return 1
  fi

  printf 'ok - %s package case\n' "$state"
}

run_case "present" "pkg present imagemagick yazi"
run_case "missing" $'pkg present imagemagick yazi\npkg add imagemagick yazi'

if rg -n '(apt|dpkg|\.deb|xorg|i3-wm|i3lock|picom|sddm|polybar|rofi|snapd)' "$ROOT_DIR/scripts/10-omarchy-packages.sh"; then
  echo "not ok - Omarchy package component contains a forbidden Debian package path" >&2
  exit 1
fi

echo "ok - Omarchy package component excludes Debian package paths"
