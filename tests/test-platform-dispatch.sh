#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BOOTSTRAP_TEST_MODE=true
source "$ROOT_DIR/bootstrap.sh"

failures=0

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "$actual" == "$expected" ]]; then
    printf 'ok - %s\n' "$label"
  else
    printf 'not ok - %s\n  expected: %q\n  actual:   %q\n' "$label" "$expected" "$actual" >&2
    failures=$((failures + 1))
  fi
}

assert_fails_with() {
  local expected="$1"
  local label="$2"
  shift 2
  local output status

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e

  if [[ $status -ne 0 && "$output" == *"$expected"* ]]; then
    printf 'ok - %s\n' "$label"
  else
    printf 'not ok - %s\n  status: %s\n  output: %s\n' "$label" "$status" "$output" >&2
    failures=$((failures + 1))
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

printf 'ID=debian\n' >"$tmp_dir/debian-release"
printf 'ID=omarchy\n' >"$tmp_dir/omarchy-release"
printf 'ID=arch\n' >"$tmp_dir/unsupported-release"

BOOTSTRAP_OS_RELEASE="$tmp_dir/debian-release"
assert_eq "debian" "$(detect_platform)" "detect Debian from os-release"

BOOTSTRAP_OS_RELEASE="$tmp_dir/omarchy-release"
assert_eq "omarchy" "$(detect_platform)" "detect Omarchy from os-release"

BOOTSTRAP_OS_RELEASE="$tmp_dir/unsupported-release"
assert_fails_with "Unsupported platform: arch" "reject unsupported auto-detected platform" detect_platform

PLATFORM_REQUESTED="debian"
PLATFORM=""
resolve_platform
assert_eq "debian" "$PLATFORM" "explicit platform override bypasses host detection"

assert_eq "yes" "$(component_supports_platform 10-base-packages.sh debian && echo yes || echo no)" "Debian base component is Debian-compatible"
assert_eq "no" "$(component_supports_platform 10-base-packages.sh omarchy && echo yes || echo no)" "Debian base component is blocked on Omarchy"
assert_eq "yes" "$(component_supports_platform 10-omarchy-packages.sh omarchy && echo yes || echo no)" "Omarchy-named component is Omarchy-compatible"
assert_eq "no" "$(component_supports_platform 10-omarchy-packages.sh debian && echo yes || echo no)" "Omarchy-named component is blocked on Debian"

PLATFORM="debian"
PROFILE="headless"
WITH_CHEZMOI="false"
WITH_PVETUI="false"
assert_eq $'05-hostname.sh\n10-base-packages.sh\n20-shell.sh\n30-cli-tools.sh\n40-python.sh\n45-editors.sh' "$(build_profile_components)" "Debian headless plan excludes GUI and optional components"

PROFILE="gui"
assert_eq $'05-hostname.sh\n10-base-packages.sh\n20-shell.sh\n30-cli-tools.sh\n40-python.sh\n45-editors.sh\n50-gui.sh' "$(build_profile_components)" "Debian GUI plan includes GUI component"

PLATFORM="omarchy"
PROFILE="gui"
assert_eq $'10-omarchy-packages.sh\n20-omarchy-shell.sh\n30-omarchy-terminal.sh\n40-omarchy-tailscale.sh' "$(build_profile_components)" "Omarchy plan includes only compatible Omarchy components"

WITH_CHEZMOI="true"
WITH_PVETUI="true"
assert_eq $'10-omarchy-packages.sh\n20-omarchy-shell.sh\n30-omarchy-terminal.sh\n40-omarchy-tailscale.sh\n56-omarchy-pvetui.sh\n60-omarchy-chezmoi.sh' "$(build_profile_components)" "Omarchy plan includes selected platform-specific optional components"
WITH_CHEZMOI="false"
WITH_PVETUI="false"

COMPONENTS_RAW="gui"
assert_fails_with "not available for platform 'omarchy'" "reject incompatible cherry-pick by name" select_cherry_pick_components

COMPONENTS_RAW="50"
assert_fails_with "not available for platform 'omarchy'" "reject incompatible cherry-pick by script prefix" select_cherry_pick_components

COMPONENTS_RAW="7"
assert_fails_with "not available for platform 'omarchy'" "reject incompatible cherry-pick by menu number" select_cherry_pick_components

PROFILE="headless"
assert_fails_with "not supported on Omarchy" "reject invalid Omarchy headless profile" validate_platform_profile

if ((failures > 0)); then
  printf '%s test(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'all platform dispatch tests passed\n'
