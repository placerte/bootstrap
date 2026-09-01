#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

printf 'ID=omarchy\n' >"$tmp_dir/os-release"
cat >"$tmp_dir/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GUI_GUARD_TEST_LOG"
EOF
chmod +x "$tmp_dir/sudo"

log_file="$tmp_dir/sudo.log"
set +e
output="$(BOOTSTRAP_OS_RELEASE="$tmp_dir/os-release" GUI_GUARD_TEST_LOG="$log_file" PATH="$tmp_dir:$PATH" bash "$ROOT_DIR/scripts/50-gui.sh" 2>&1)"
status=$?
set -e

if [[ $status -eq 0 || "$output" != *"GUI package component is Debian-only"* ]]; then
  echo "not ok - direct Omarchy invocation was not rejected clearly" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

if [[ -e "$log_file" ]]; then
  echo "not ok - direct Omarchy invocation reached a privileged package command" >&2
  cat "$log_file" >&2
  exit 1
fi

echo "ok - direct Omarchy invocation fails before package changes"

BOOTSTRAP_TEST_MODE=true source "$ROOT_DIR/bootstrap.sh"
PLATFORM="omarchy"
# The numeric token is the dynamically discovered position in the full
# component list; keep it aligned with the GUI component's current position.
for token in gui 50 12; do
  COMPONENTS_RAW="$token"
  set +e
  output="$(select_cherry_pick_components 2>&1)"
  status=$?
  set -e
  if [[ $status -eq 0 || "$output" != *"not available for platform 'omarchy'"* ]]; then
    printf 'not ok - incompatible GUI token %s was not rejected\n' "$token" >&2
    exit 1
  fi
done
echo "ok - GUI component is rejected by name, prefix, and menu number"

PLATFORM="omarchy"
PROFILE="gui"
WITH_CHEZMOI="false"
WITH_PVETUI="false"
if build_profile_components | rg -q '^50-gui\.sh$'; then
  echo "not ok - normal Omarchy plan contains the Debian GUI component" >&2
  exit 1
fi
echo "ok - normal Omarchy plan preserves its existing desktop stack"
