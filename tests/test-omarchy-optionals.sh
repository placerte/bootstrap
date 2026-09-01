#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mock_bin="$tmp_dir/bin"
test_home="$tmp_dir/home"
log_file="$tmp_dir/actions.log"
mkdir -p "$mock_bin" "$test_home/.local/bin"

cat >"$tmp_dir/chezmoi-mock" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'chezmoi %s\n' "$*" >>"$OPTIONAL_TEST_LOG"
EOF
chmod +x "$tmp_dir/chezmoi-mock"

cat >"$mock_bin/omarchy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'omarchy %s\n' "$*" >>"$OPTIONAL_TEST_LOG"

case "$*" in
  "pkg add chezmoi")
    cp "$CHEZMOI_MOCK_SOURCE" "$HOME/.local/bin/chezmoi"
    chmod +x "$HOME/.local/bin/chezmoi"
    ;;
  "pkg present pvetui") [[ "$PVETUI_TEST_STATE" == "present" ]] ;;
  "pkg aur accessible") exit 0 ;;
  "pkg aur add pvetui") exit 0 ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$mock_bin/omarchy"

run_chezmoi() {
  local apply="$1"
  HOME="$test_home" \
  OPTIONAL_TEST_LOG="$log_file" \
  CHEZMOI_MOCK_SOURCE="$tmp_dir/chezmoi-mock" \
  PATH="$mock_bin:/usr/bin" \
    bash "$ROOT_DIR/scripts/60-omarchy-chezmoi.sh" https://example.invalid/dotfiles.git "$apply" >/dev/null
}

cp "$tmp_dir/chezmoi-mock" "$test_home/.local/bin/chezmoi"
run_chezmoi false
if [[ -s "$log_file" ]]; then
  echo "not ok - existing chezmoi was reinstalled or applied" >&2
  cat "$log_file" >&2
  exit 1
fi
echo "ok - existing chezmoi is neither reinstalled nor implicitly applied"

rm -f "$test_home/.local/bin/chezmoi" "$log_file"
run_chezmoi false
if [[ "$(cat "$log_file")" != "omarchy pkg add chezmoi" ]]; then
  echo "not ok - missing chezmoi install performed unexpected actions" >&2
  cat "$log_file" >&2
  exit 1
fi
echo "ok - missing chezmoi installs without applying dotfiles"

rm -f "$log_file"
run_chezmoi true
if [[ "$(cat "$log_file")" != "chezmoi init --apply https://example.invalid/dotfiles.git" ]]; then
  echo "not ok - explicit chezmoi apply did not use the configured repository" >&2
  cat "$log_file" >&2
  exit 1
fi
echo "ok - explicit apply uses the configured external repository"

run_pvetui() {
  local state="$1"
  rm -f "$log_file"
  HOME="$test_home" \
  OPTIONAL_TEST_LOG="$log_file" \
  PVETUI_TEST_STATE="$state" \
  PATH="$mock_bin:/usr/bin" \
    bash "$ROOT_DIR/scripts/56-omarchy-pvetui.sh" >/dev/null
}

run_pvetui present
if [[ "$(cat "$log_file")" != "omarchy pkg present pvetui" ]]; then
  echo "not ok - present pvetui was reinstalled" >&2
  exit 1
fi
echo "ok - existing pvetui is a no-op"

run_pvetui missing
expected=$'omarchy pkg present pvetui\nomarchy pkg aur accessible\nomarchy pkg aur add pvetui'
if [[ "$(cat "$log_file")" != "$expected" ]]; then
  echo "not ok - missing pvetui did not use the AUR path" >&2
  cat "$log_file" >&2
  exit 1
fi
echo "ok - missing pvetui uses the supported AUR path"

if rg -n '(apt|dpkg|\.deb)' "$ROOT_DIR/scripts/56-omarchy-pvetui.sh"; then
  echo "not ok - Omarchy pvetui component contains a Debian artifact path" >&2
  exit 1
fi
echo "ok - Omarchy pvetui never uses Debian artifacts"
