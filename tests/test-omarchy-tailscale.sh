#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mock_bin="$tmp_dir/bin"
state_dir="$tmp_dir/state"
mkdir -p "$mock_bin" "$state_dir"
log_file="$tmp_dir/actions.log"

cat >"$mock_bin/omarchy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'omarchy %s\n' "$*" >>"$TAILSCALE_TEST_LOG"
[[ "$*" == "pkg add tailscale" ]]
cp "$TAILSCALE_MOCK_SOURCE" "$TAILSCALE_MOCK_BIN/tailscale"
chmod +x "$TAILSCALE_MOCK_BIN/tailscale"
EOF

cat >"$tmp_dir/tailscale-mock" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  status)
    state="$(cat "$TAILSCALE_TEST_STATE/backend")"
    printf '{"BackendState":"%s"}\n' "$state"
    ;;
  up)
    printf 'tailscale up\n' >>"$TAILSCALE_TEST_LOG"
    printf 'Running\n' >"$TAILSCALE_TEST_STATE/backend"
    ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$tmp_dir/tailscale-mock" "$mock_bin/omarchy"

cat >"$mock_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "is-active" ]]; then
  [[ -e "$TAILSCALE_TEST_STATE/active" ]]
else
  exit 2
fi
EOF

cat >"$mock_bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >>"$TAILSCALE_TEST_LOG"
if [[ "$1" == "systemctl" ]]; then
  touch "$TAILSCALE_TEST_STATE/active"
elif [[ "$1 $2" == "tailscale up" ]]; then
  tailscale up
else
  exit 2
fi
EOF
chmod +x "$mock_bin/systemctl" "$mock_bin/sudo"

reset_case() {
  rm -f "$mock_bin/tailscale" "$state_dir/active" "$log_file"
  printf '%s\n' "$1" >"$state_dir/backend"
}

run_component() {
  local assume_yes="$1"
  local activate="$2"
  shift 2
  TAILSCALE_TEST_LOG="$log_file" \
  TAILSCALE_TEST_STATE="$state_dir" \
  TAILSCALE_MOCK_SOURCE="$tmp_dir/tailscale-mock" \
  TAILSCALE_MOCK_BIN="$mock_bin" \
  PATH="$mock_bin:$PATH" \
    bash "$ROOT_DIR/scripts/40-omarchy-tailscale.sh" "$assume_yes" "$activate" "$@"
}

reset_case "NeedsLogin"
run_component true false >/dev/null
expected=$'omarchy pkg add tailscale\nsudo systemctl enable --now tailscaled.service'
if [[ "$(cat "$log_file")" != "$expected" ]]; then
  echo "not ok - fresh unattended install performed unexpected actions" >&2
  cat "$log_file" >&2
  exit 1
fi
echo "ok - fresh unattended install starts service without activation"

reset_case "NeedsLogin"
cp "$tmp_dir/tailscale-mock" "$mock_bin/tailscale"
touch "$state_dir/active"
run_component true true >/dev/null
if [[ "$(cat "$log_file")" != $'sudo tailscale up\ntailscale up' ]]; then
  echo "not ok - explicit activation did not run tailscale up exactly once" >&2
  cat "$log_file" >&2
  exit 1
fi
echo "ok - --tailscale-up explicitly activates an unauthenticated node"

reset_case "NeedsLogin"
cp "$tmp_dir/tailscale-mock" "$mock_bin/tailscale"
touch "$state_dir/active"
printf 'y\n' | run_component false false >/dev/null
grep -qx 'sudo tailscale up' "$log_file"
echo "ok - interactive consent activates Tailscale"

reset_case "Running"
cp "$tmp_dir/tailscale-mock" "$mock_bin/tailscale"
touch "$state_dir/active"
run_component true false >/dev/null
if [[ -s "$log_file" ]]; then
  echo "not ok - connected rerun changed Tailscale state" >&2
  cat "$log_file" >&2
  exit 1
fi
echo "ok - connected rerun is a no-op"

if rg -n '(curl|wget|tailscale\.com/install)' "$ROOT_DIR/scripts/40-omarchy-tailscale.sh"; then
  echo "not ok - Omarchy Tailscale component contains an upstream installer pipeline" >&2
  exit 1
fi
echo "ok - Omarchy Tailscale component has no upstream installer pipeline"
