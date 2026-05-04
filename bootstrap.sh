#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_REPO_URL="https://raw.githubusercontent.com/placerte/bootstrap/main"
BOOTSTRAP_API_URL="https://api.github.com/repos/placerte/bootstrap/contents/scripts?ref=main"
BOOTSTRAP_WORKDIR="${TMPDIR:-/tmp}/bootstrap.$$"
SCRIPTS_DIR=""

PROFILE=""
WITH_CHEZMOI="false"
CHEZMOI_CHOICE_SET="false"
WITH_PVETUI="false"
PVETUI_CHOICE_SET="false"
ASSUME_YES="false"
DOTFILES_REPO="https://github.com/placerte/dotfiles.git"
COMPONENTS_RAW=""
TOTAL_STEPS=6

CHERRY_PICK_FILES=()

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib.sh" 2>/dev/null || true

if [[ -z "${C_RESET:-}" ]]; then
  if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
  else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_BLUE=""
    C_CYAN=""
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
  fi
fi

usage() {
  cat <<'EOF'
Usage:
  bootstrap.sh [options]

Options:
  --profile <headless|gui|cherry-pick>
  --components <comma-or-space-separated list>
  --with-chezmoi
  --without-chezmoi
  --with-pvetui
  --without-pvetui
  --dotfiles-repo <git-url>
  --yes
  --help
EOF
}

print_banner() {
  printf '%s\n' "${C_CYAN}${C_BOLD}"
  printf '  ____              __        __                   __\n'
  printf ' / __ )____  ____  / /_______/ /__________ _____  / /\n'
  printf '/ __  / __ \/ __ \/ __/ ___/ __/ ___/ __ `/ __ \/ / \n'
  printf '/ /_/ / /_/ / /_/ / /_(__  ) /_/ /  / /_/ / /_/ / /  \n'
  printf '/_____/\____/\____/\__/____/\__/_/   \__,_/ .___/_/   \n'
  printf '                                         /_/         \n'
  printf '%s\n' "${C_RESET}"
  printf '%sFresh Debian machine bootstrap%s\n' "${C_DIM}" "${C_RESET}"
}

log() {
  printf '\n%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"
}

success() {
  printf '%s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"
}

warn() {
  printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
}

fail() {
  printf '%s✘%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
}

draw_rule() {
  printf '%s------------------------------------------------------------%s\n' "$C_DIM" "$C_RESET"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

download_to_file() {
  local url="$1"
  local dest="$2"

  if have_cmd wget; then
    wget -qO "$dest" "$url"
  elif have_cmd curl; then
    curl -fsSL "$url" -o "$dest"
  else
    fail "Need wget or curl to download bootstrap resources"
    exit 1
  fi
}

download_to_stdout() {
  local url="$1"

  if have_cmd wget; then
    wget -qO- "$url"
  elif have_cmd curl; then
    curl -fsSL "$url"
  else
    fail "Need wget or curl to download bootstrap resources"
    exit 1
  fi
}

is_helper_script() {
  case "$1" in
    lib.sh|install-yazi.sh) return 0 ;;
    *) return 1 ;;
  esac
}

is_component_script() {
  local file="$1"

  [[ "$file" =~ ^[0-9][0-9]-.*\.sh$ ]] || return 1

  case "$file" in
    00-preflight.sh|70-postflight.sh) return 1 ;;
    *) return 0 ;;
  esac
}

component_title() {
  case "$1" in
    05-hostname.sh) echo "Hostname check" ;;
    10-base-packages.sh) echo "Base packages" ;;
    20-shell.sh) echo "Shell setup" ;;
    30-cli-tools.sh) echo "CLI tools" ;;
    40-python.sh) echo "Python tooling" ;;
    45-editors.sh) echo "Editors" ;;
    50-gui.sh) echo "GUI packages" ;;
    55-taskwarrior.sh) echo "Optional Taskwarrior build" ;;
    56-pvetui.sh) echo "Optional pvetui install" ;;
    60-chezmoi.sh) echo "chezmoi setup" ;;
    *)
      local label="$1"
      label="${label#??-}"
      label="${label%.sh}"
      label="${label//-/ }"
      echo "$label"
      ;;
  esac
}

component_description() {
  case "$1" in
    05-hostname.sh) echo "Prompt to fix hostname early, useful for cloned VMs" ;;
    10-base-packages.sh) echo "Core Debian packages used by the rest of the bootstrap" ;;
    20-shell.sh) echo "Shell baseline such as zsh and related setup" ;;
    30-cli-tools.sh) echo "Terminal toolbelt including utilities like yazi and tailscale" ;;
    40-python.sh) echo "Python tooling and pip-based helpers" ;;
    45-editors.sh) echo "Editors such as Neovim and related packages" ;;
    50-gui.sh) echo "Xorg, i3, polybar, kitty, themes, and desktop tools" ;;
    55-taskwarrior.sh) echo "Optional Taskwarrior 3.x source-build flow" ;;
    56-pvetui.sh) echo "Pinned pvetui .deb install for Proxmox-oriented machines" ;;
    60-chezmoi.sh) echo "Install and initialize chezmoi using the configured dotfiles repo" ;;
    *) echo "Bootstrap component" ;;
  esac
}

fetch_remote_script_list() {
  download_to_stdout "$BOOTSTRAP_API_URL" \
    | grep -o '"name": *"[^"]*"' \
    | sed 's/.*"name": *"//; s/"$//' \
    | sort -V
}

list_bootstrap_script_files() {
  local source_path source_dir
  source_path="${BASH_SOURCE[0]:-}"
  source_dir="$(cd "$(dirname "$source_path")" 2>/dev/null && pwd || true)"

  if [[ -n "$source_dir" && -d "$source_dir/scripts" ]]; then
    find "$source_dir/scripts" -maxdepth 1 -type f -printf '%f\n' | sort -V
    return 0
  fi

  if fetch_remote_script_list; then
    return 0
  fi

  cat <<'EOF'
00-preflight.sh
05-hostname.sh
10-base-packages.sh
20-shell.sh
30-cli-tools.sh
40-python.sh
45-editors.sh
50-gui.sh
55-taskwarrior.sh
56-pvetui.sh
60-chezmoi.sh
70-postflight.sh
install-yazi.sh
lib.sh
EOF
}

prepare_scripts_dir() {
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    local source_path="${BASH_SOURCE[0]}"
    local source_dir
    source_dir="$(cd "$(dirname "$source_path")" 2>/dev/null && pwd || true)"
    if [[ -n "$source_dir" && -d "$source_dir/scripts" ]]; then
      SCRIPTS_DIR="$source_dir/scripts"
      return 0
    fi
  fi

  mkdir -p "$BOOTSTRAP_WORKDIR/scripts"
  SCRIPTS_DIR="$BOOTSTRAP_WORKDIR/scripts"

  local file
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    case "$file" in
      *.sh) ;;
      *) continue ;;
    esac
    download_to_file "$BOOTSTRAP_REPO_URL/scripts/$file" "$SCRIPTS_DIR/$file"
    chmod +x "$SCRIPTS_DIR/$file"
  done < <(list_bootstrap_script_files)
}

cleanup() {
  if [[ -d "$BOOTSTRAP_WORKDIR" ]]; then
    rm -rf "$BOOTSTRAP_WORKDIR"
  fi
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local reply

  if [[ "$ASSUME_YES" == "true" ]]; then
    return 0
  fi

  if [[ "$default" == "y" ]]; then
    read -r -p "$prompt [Y/n] " reply
    [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]
  else
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
  fi
}

render_profile_menu() {
  if have_cmd tput && tput clear >/dev/null 2>&1; then
    tput clear
  else
    printf '\n\n'
  fi
  print_banner
  draw_rule
  printf '%sSelect install profile%s\n\n' "$C_BOLD" "$C_RESET"
  printf '  %s1)%s headless     %sTerminal-first setup for servers, VMs, and minimal systems%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '  %s2)%s gui          %sHeadless setup plus Xorg, i3, kitty, polybar, and friends%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '  %s3)%s cherry-pick  %sRun selected bootstrap components on demand%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '\n'
}

prompt_profile() {
  if [[ -n "$PROFILE" ]]; then
    return 0
  fi

  if [[ "$ASSUME_YES" == "true" ]]; then
    PROFILE="headless"
    return 0
  fi

  local choice
  while true; do
    render_profile_menu
    read -r -p "Choice [1/2/3]: " choice
    case "${choice:-1}" in
      1) PROFILE="headless"; break ;;
      2) PROFILE="gui"; break ;;
      3) PROFILE="cherry-pick"; break ;;
      *) warn "Invalid choice, please select 1, 2, or 3." ;;
    esac
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        PROFILE="$2"
        shift 2
        ;;
      --components)
        COMPONENTS_RAW="$2"
        shift 2
        ;;
      --with-chezmoi)
        WITH_CHEZMOI="true"
        CHEZMOI_CHOICE_SET="true"
        shift
        ;;
      --without-chezmoi)
        WITH_CHEZMOI="false"
        CHEZMOI_CHOICE_SET="true"
        shift
        ;;
      --with-pvetui)
        WITH_PVETUI="true"
        PVETUI_CHOICE_SET="true"
        shift
        ;;
      --without-pvetui)
        WITH_PVETUI="false"
        PVETUI_CHOICE_SET="true"
        shift
        ;;
      --dotfiles-repo)
        DOTFILES_REPO="$2"
        shift 2
        ;;
      --yes)
        ASSUME_YES="true"
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  if [[ -n "$PROFILE" && "$PROFILE" != "headless" && "$PROFILE" != "gui" && "$PROFILE" != "cherry-pick" ]]; then
    fail "Invalid profile: $PROFILE"
    echo "Expected one of: headless, gui, cherry-pick"
    exit 1
  fi

  if [[ "$ASSUME_YES" == "true" && "$PROFILE" == "cherry-pick" && -z "$COMPONENTS_RAW" ]]; then
    fail "Non-interactive cherry-pick mode requires --components"
    exit 1
  fi
}

run_step() {
  local current="$1"
  local title="$2"
  local script="$3"

  printf '\n%s[%s/%s]%s %s%s%s\n' "$C_DIM" "$current" "$TOTAL_STEPS" "$C_RESET" "$C_BOLD" "$title" "$C_RESET"
  draw_rule

  case "$script" in
    00-preflight.sh)
      bash "$SCRIPTS_DIR/$script" "$PROFILE"
      ;;
    05-hostname.sh|30-cli-tools.sh|55-taskwarrior.sh)
      bash "$SCRIPTS_DIR/$script" "$ASSUME_YES"
      ;;
    60-chezmoi.sh)
      bash "$SCRIPTS_DIR/$script" "$DOTFILES_REPO"
      ;;
    70-postflight.sh)
      bash "$SCRIPTS_DIR/$script" "$PROFILE" "$WITH_CHEZMOI" "$WITH_PVETUI"
      ;;
    *)
      bash "$SCRIPTS_DIR/$script"
      ;;
  esac

  success "$title complete"
}

get_component_files() {
  local file
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    if is_component_script "$file"; then
      echo "$file"
    fi
  done < <(list_bootstrap_script_files)
}

render_cherry_pick_menu() {
  local components=("$@")
  local idx file

  if have_cmd tput && tput clear >/dev/null 2>&1; then
    tput clear
  else
    printf '\n\n'
  fi

  print_banner
  draw_rule
  printf '%sCherry-pick components%s\n\n' "$C_BOLD" "$C_RESET"

  for idx in "${!components[@]}"; do
    file="${components[$idx]}"
    printf '  %s%2d)%s %-20s %s%s%s\n' \
      "$C_CYAN" "$((idx + 1))" "$C_RESET" \
      "$(component_title "$file")" \
      "$C_DIM" "$(component_description "$file")" "$C_RESET"
  done

  printf '\n'
  printf '%sEnter one or more selections separated by spaces or commas.%s\n' "$C_DIM" "$C_RESET"
  printf '%sYou can use menu numbers, script prefixes like 56, or names like pvetui.%s\n\n' "$C_DIM" "$C_RESET"
}

append_component_once() {
  local file="$1"
  local existing

  for existing in "${CHERRY_PICK_FILES[@]:-}"; do
    [[ "$existing" == "$file" ]] && return 0
  done

  CHERRY_PICK_FILES+=("$file")
}

resolve_component_token() {
  local token="$1"
  shift
  local components=("$@")
  local normalized file prefix title slug idx

  normalized="${token,,}"
  normalized="${normalized//_/ -}"
  normalized="${normalized//,/}"

  for idx in "${!components[@]}"; do
    file="${components[$idx]}"
    prefix="${file%%-*}"
    title="$(component_title "$file")"
    slug="${title,,}"
    slug="${slug// /-}"

    if [[ "$token" == "$((idx + 1))" || "$token" == "$prefix" || "$normalized" == "$slug" || "$normalized" == "${slug//-/}" ]]; then
      echo "$file"
      return 0
    fi

    if [[ "$normalized" == *pvetui* && "$file" == "56-pvetui.sh" ]]; then
      echo "$file"
      return 0
    fi
    if [[ "$normalized" == *chezmoi* && "$file" == "60-chezmoi.sh" ]]; then
      echo "$file"
      return 0
    fi
    if [[ "$normalized" == *taskwarrior* && "$file" == "55-taskwarrior.sh" ]]; then
      echo "$file"
      return 0
    fi
    if [[ "$normalized" == *gui* && "$file" == "50-gui.sh" ]]; then
      echo "$file"
      return 0
    fi
    if [[ "$normalized" == *python* && "$file" == "40-python.sh" ]]; then
      echo "$file"
      return 0
    fi
    if [[ "$normalized" == *editor* && "$file" == "45-editors.sh" ]]; then
      echo "$file"
      return 0
    fi
    if [[ "$normalized" == *shell* && "$file" == "20-shell.sh" ]]; then
      echo "$file"
      return 0
    fi
    if [[ "$normalized" == *base* && "$file" == "10-base-packages.sh" ]]; then
      echo "$file"
      return 0
    fi
    if [[ "$normalized" == *hostname* && "$file" == "05-hostname.sh" ]]; then
      echo "$file"
      return 0
    fi
    if [[ "$normalized" == *cli* && "$file" == "30-cli-tools.sh" ]]; then
      echo "$file"
      return 0
    fi
  done

  return 1
}

select_cherry_pick_components() {
  mapfile -t available_components < <(get_component_files)

  if [[ ${#available_components[@]} -eq 0 ]]; then
    fail "No selectable bootstrap components were found"
    exit 1
  fi

  CHERRY_PICK_FILES=()

  local raw_input token resolved

  if [[ -n "$COMPONENTS_RAW" ]]; then
    raw_input="$COMPONENTS_RAW"
  else
    while true; do
      render_cherry_pick_menu "${available_components[@]}"
      read -r -p "Components: " raw_input
      [[ -n "$raw_input" ]] || { warn "Please select at least one component."; continue; }
      break
    done
  fi

  raw_input="${raw_input//,/ }"
  for token in $raw_input; do
    if resolved="$(resolve_component_token "$token" "${available_components[@]}")"; then
      append_component_once "$resolved"
    else
      fail "Unknown component selection: $token"
      exit 1
    fi
  done

  if [[ ${#CHERRY_PICK_FILES[@]} -eq 0 ]]; then
    fail "No valid cherry-pick components were selected"
    exit 1
  fi

  mapfile -t CHERRY_PICK_FILES < <(printf '%s\n' "${CHERRY_PICK_FILES[@]}" | sort -V)
}

main() {
  trap cleanup EXIT

  parse_args "$@"

  export TERM="${TERM:-xterm-256color}"

  prepare_scripts_dir

  print_banner
  prompt_profile

  if [[ "$PROFILE" == "cherry-pick" ]]; then
    select_cherry_pick_components
    WITH_CHEZMOI="false"
    WITH_PVETUI="false"

    local selected
    for selected in "${CHERRY_PICK_FILES[@]}"; do
      [[ "$selected" == "60-chezmoi.sh" ]] && WITH_CHEZMOI="true"
      [[ "$selected" == "56-pvetui.sh" ]] && WITH_PVETUI="true"
    done

    TOTAL_STEPS=$((2 + ${#CHERRY_PICK_FILES[@]}))

    log "Bootstrap plan"
    echo "Profile      : $PROFILE"
    echo "chezmoi      : $WITH_CHEZMOI"
    echo "pvetui       : $WITH_PVETUI"
    echo "dotfiles repo: $DOTFILES_REPO"
    echo "components   :"
    for selected in "${CHERRY_PICK_FILES[@]}"; do
      printf '  - %s (%s)\n' "$(component_title "$selected")" "$selected"
    done

    local step=1
    run_step "$step" "Preflight checks" 00-preflight.sh
    step=$((step + 1))

    for selected in "${CHERRY_PICK_FILES[@]}"; do
      run_step "$step" "$(component_title "$selected")" "$selected"
      step=$((step + 1))
    done

    run_step "$step" "Postflight summary" 70-postflight.sh
    printf '\n%sBootstrap complete.%s\n' "$C_GREEN$C_BOLD" "$C_RESET"
    return 0
  fi

  if [[ "$CHEZMOI_CHOICE_SET" != "true" ]]; then
    if prompt_yes_no "Install and initialize chezmoi as part of bootstrap?" y; then
      WITH_CHEZMOI="true"
    else
      WITH_CHEZMOI="false"
    fi
  fi

  if [[ "$PVETUI_CHOICE_SET" != "true" ]]; then
    if prompt_yes_no "Install pvetui as an optional Proxmox helper?" n; then
      WITH_PVETUI="true"
    else
      WITH_PVETUI="false"
    fi
  fi

  if [[ "$PROFILE" == "gui" ]]; then
    TOTAL_STEPS=9
  else
    TOTAL_STEPS=8
  fi

  if [[ "$WITH_CHEZMOI" == "true" ]]; then
    TOTAL_STEPS=$((TOTAL_STEPS + 1))
  fi

  if [[ "$WITH_PVETUI" == "true" ]]; then
    TOTAL_STEPS=$((TOTAL_STEPS + 1))
  fi

  log "Bootstrap plan"
  echo "Profile      : $PROFILE"
  echo "chezmoi      : $WITH_CHEZMOI"
  echo "pvetui       : $WITH_PVETUI"
  echo "dotfiles repo: $DOTFILES_REPO"

  run_step 1 "Preflight checks" 00-preflight.sh
  run_step 2 "Hostname check" 05-hostname.sh
  run_step 3 "Base packages" 10-base-packages.sh
  run_step 4 "Shell setup" 20-shell.sh
  run_step 5 "CLI tools" 30-cli-tools.sh
  run_step 6 "Python tooling" 40-python.sh
  run_step 7 "Editors" 45-editors.sh

  local step=8
  if [[ "$PROFILE" == "gui" ]]; then
    run_step "$step" "GUI packages" 50-gui.sh
    step=$((step + 1))
  fi

  run_step "$step" "Optional Taskwarrior build" 55-taskwarrior.sh
  step=$((step + 1))

  if [[ "$WITH_PVETUI" == "true" ]]; then
    run_step "$step" "Optional pvetui install" 56-pvetui.sh
    step=$((step + 1))
  fi

  if [[ "$WITH_CHEZMOI" == "true" ]]; then
    run_step "$step" "chezmoi setup" 60-chezmoi.sh
    step=$((step + 1))
  fi

  run_step "$step" "Postflight summary" 70-postflight.sh

  printf '\n%sBootstrap complete.%s\n' "$C_GREEN$C_BOLD" "$C_RESET"
}

main "$@"
