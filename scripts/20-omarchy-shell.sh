#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# GitHub issue #3: pin the exact tested upstream revision. Updating ble.sh is a
# deliberate bootstrap change rather than an implicit latest-version fetch.
BLESH_REF="63c23e99f1f7133ae57b79f87b16d1f68cd39884"
BLESH_REPO="https://github.com/akinomyoga/ble.sh.git"
BLESH_PREFIX="${BLESH_PREFIX:-$HOME/.local}"
BLESH_INSTALL_DIR="$BLESH_PREFIX/share/blesh"
BLESH_REF_FILE="$BLESH_INSTALL_DIR/.bootstrap-ref"
BASHRC_PATH="${BASHRC_PATH:-$HOME/.bashrc}"
BLERC_PATH="${BLERC_PATH:-$HOME/.blerc}"

install_blesh() {
  if [[ -r "$BLESH_INSTALL_DIR/ble.sh" && -r "$BLESH_REF_FILE" ]] &&
    [[ "$(<"$BLESH_REF_FILE")" == "$BLESH_REF" ]]; then
    success "ble.sh $BLESH_REF is already installed"
    return 0
  fi

  local command_name
  for command_name in git make gawk; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      fail "Installing ble.sh requires $command_name"
      return 1
    fi
  done

  local build_dir
  build_dir="$(mktemp -d)"
  trap 'rm -rf "$build_dir"' EXIT

  log "Installing pinned ble.sh revision $BLESH_REF"
  git -C "$build_dir" init --quiet
  git -C "$build_dir" remote add origin "$BLESH_REPO"
  git -C "$build_dir" fetch --quiet --depth 1 origin "$BLESH_REF"
  git -C "$build_dir" checkout --quiet --detach FETCH_HEAD
  git -C "$build_dir" submodule update --init --recursive --depth 1
  make -C "$build_dir" install PREFIX="$BLESH_PREFIX"
  printf '%s\n' "$BLESH_REF" >"$BLESH_REF_FILE"
  rm -rf "$build_dir"
  trap - EXIT
}

configure_bashrc() {
  local begin_load="# >>> bootstrap ble.sh load >>>"
  local end_load="# <<< bootstrap ble.sh load <<<"
  local begin_attach="# >>> bootstrap ble.sh attach >>>"
  local end_attach="# <<< bootstrap ble.sh attach <<<"
  local load_block attach_block tmp_file

  load_block="$begin_load
[[ \$- == *i* && -r \"\$HOME/.local/share/blesh/ble.sh\" ]] && \\
  source -- \"\$HOME/.local/share/blesh/ble.sh\" --attach=none
$end_load"
  attach_block="$begin_attach
[[ ! \${BLE_VERSION-} ]] || ble-attach
$end_attach"

  mkdir -p "$(dirname "$BASHRC_PATH")"
  touch "$BASHRC_PATH"
  tmp_file="$(mktemp)"

  awk -v begin_load="$begin_load" -v end_load="$end_load" \
      -v begin_attach="$begin_attach" -v end_attach="$end_attach" \
      -v load_block="$load_block" '
    $0 == begin_load || $0 == begin_attach { skipping=1; next }
    $0 == end_load || $0 == end_attach { skipping=0; next }
    skipping { next }
    $0 == "# Load ble.sh early and attach it after Omarchy finishes configuring Bash." { legacy=2; next }
    legacy > 0 { legacy--; next }
    $0 == "[[ ! ${BLE_VERSION-} ]] || ble-attach" { next }
    !inserted && $0 ~ /^\[\[ \$- != \*i\* \]\] && return$/ {
      print load_block
      print ""
      inserted=1
    }
    { print }
    END {
      if (!inserted) {
        print ""
        print load_block
      }
    }
  ' "$BASHRC_PATH" >"$tmp_file"

  printf '\n%s\n' "$attach_block" >>"$tmp_file"
  chmod --reference="$BASHRC_PATH" "$tmp_file" 2>/dev/null || chmod 0644 "$tmp_file"
  mv "$tmp_file" "$BASHRC_PATH"
}

configure_blerc() {
  local begin="# >>> bootstrap Omarchy ANSI theme >>>"
  local end="# <<< bootstrap Omarchy ANSI theme <<<"
  local tmp_file

  mkdir -p "$(dirname "$BLERC_PATH")"
  touch "$BLERC_PATH"
  tmp_file="$(mktemp)"

  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skipping=1; next }
    $0 == end { skipping=0; next }
    skipping { next }
    { print }
  ' "$BLERC_PATH" >"$tmp_file"

  cat >>"$tmp_file" <<'EOF'

# >>> bootstrap Omarchy ANSI theme >>>
# Named ANSI colors inherit the active Omarchy terminal palette.
ble-face syntax_command='fg=blue'
ble-face syntax_quoted='fg=green'
ble-face syntax_quotation='fg=green,bold'
ble-face syntax_escape='fg=magenta'
ble-face syntax_expr='fg=cyan'
ble-face syntax_error='fg=red,bold'
ble-face syntax_varname='fg=cyan'
ble-face syntax_delimiter='bold'
ble-face syntax_param_expansion='fg=cyan'
ble-face syntax_function_name='fg=blue,bold'
ble-face syntax_comment='fg=gray'
ble-face syntax_glob='fg=magenta,bold'
ble-face syntax_brace='fg=cyan,bold'
ble-face syntax_tilde='fg=blue,bold'
ble-face auto_complete='fg=gray,italic'
# <<< bootstrap Omarchy ANSI theme <<<
EOF

  chmod --reference="$BLERC_PATH" "$tmp_file" 2>/dev/null || chmod 0644 "$tmp_file"
  mv "$tmp_file" "$BLERC_PATH"
}

install_blesh
configure_bashrc
configure_blerc
success "Omarchy Bash enhancements are configured"
