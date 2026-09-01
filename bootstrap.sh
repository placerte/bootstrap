#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_REPO_URL="https://raw.githubusercontent.com/placerte/bootstrap/main"
BOOTSTRAP_API_URL="https://api.github.com/repos/placerte/bootstrap/contents/scripts?ref=main"
BOOTSTRAP_WORKDIR="${TMPDIR:-/tmp}/bootstrap.$$"
SCRIPTS_DIR=""

PROFILE=""
PLATFORM=""
PLATFORM_REQUESTED="auto"
WITH_CHEZMOI="false"
CHEZMOI_CHOICE_SET="false"
APPLY_CHEZMOI="false"
APPLY_CHEZMOI_CHOICE_SET="false"
WITH_PVETUI="false"
PVETUI_CHOICE_SET="false"
ASSUME_YES="false"
TAILSCALE_UP="false"
DRY_RUN="false"
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
  --platform <auto|debian|omarchy>
  --profile <headless|gui|cherry-pick>
  --components <comma-or-space-separated list>
  --with-chezmoi
  --without-chezmoi
  --apply-chezmoi
  --without-apply-chezmoi
  --with-pvetui
  --without-pvetui
  --dotfiles-repo <git-url>
  --yes
  --tailscale-up
  --dry-run
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
  printf '%sFresh Debian and Omarchy machine bootstrap%s\n' "${C_DIM}" "${C_RESET}"
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

# GitHub issue #2: platform compatibility is explicit so discovery can never
# make a Debian-only script selectable on Omarchy (or vice versa).
component_supports_platform() {
  local file="$1"
  local platform="$2"

  case "$file" in
    00-preflight.sh|70-postflight.sh) return 0 ;;
    05-hostname.sh|10-base-packages.sh|20-shell.sh|30-cli-tools.sh|40-python.sh|45-editors.sh|50-gui.sh|56-pvetui.sh|60-chezmoi.sh)
      [[ "$platform" == "debian" ]]
      ;;
    15-keyboard.sh)
      [[ "$platform" == "debian" || "$platform" == "omarchy" ]]
      ;;
    *-omarchy-*.sh|??-omarchy.sh)
      [[ "$platform" == "omarchy" ]]
      ;;
    *) return 1 ;;
  esac
}

detect_platform() {
  local os_release="${BOOTSTRAP_OS_RELEASE:-/etc/os-release}"
  local os_id=""

  if [[ -r "$os_release" ]]; then
    os_id="$(. "$os_release"; printf '%s' "${ID:-}")"
  fi

  case "$os_id" in
    omarchy) echo "omarchy" ;;
    debian) echo "debian" ;;
    *)
      fail "Unsupported platform: ${os_id:-unknown}"
      echo "Use --platform debian or --platform omarchy to override detection." >&2
      return 1
      ;;
  esac
}

resolve_platform() {
  if [[ "$PLATFORM_REQUESTED" == "auto" ]]; then
    PLATFORM="$(detect_platform)" || exit 1
  else
    PLATFORM="$PLATFORM_REQUESTED"
  fi
}

validate_platform_profile() {
  if [[ "$PLATFORM" == "omarchy" && "$PROFILE" == "headless" ]]; then
    fail "Profile 'headless' is not supported on Omarchy"
    echo "Use --profile gui for the standard Omarchy path, or --profile cherry-pick." >&2
    exit 1
  fi
}

component_title() {
  case "$1" in
    05-hostname.sh) echo "Hostname check" ;;
    10-base-packages.sh) echo "Base packages" ;;
    15-keyboard.sh) echo "Keyboard layout" ;;
    10-omarchy-packages.sh) echo "Omarchy packages" ;;
    20-shell.sh) echo "Shell setup" ;;
    20-omarchy-shell.sh) echo "Omarchy shell enhancements" ;;
    30-cli-tools.sh) echo "CLI tools" ;;
    30-omarchy-terminal.sh) echo "Kitty and Yazi previews" ;;
    40-python.sh) echo "Python tooling" ;;
    40-omarchy-tailscale.sh) echo "Tailscale service" ;;
    45-editors.sh) echo "Editors" ;;
    50-gui.sh) echo "GUI packages" ;;
    56-pvetui.sh) echo "Optional pvetui install" ;;
    56-omarchy-pvetui.sh) echo "Optional Omarchy pvetui install" ;;
    60-chezmoi.sh) echo "chezmoi setup" ;;
    60-omarchy-chezmoi.sh) echo "Omarchy chezmoi setup" ;;
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
    15-keyboard.sh) echo "Configure the Canadian Multilingual (ca/multix) keyboard layout" ;;
    10-omarchy-packages.sh) echo "Reviewed additions installed through Omarchy's package helper" ;;
    20-shell.sh) echo "Shell baseline such as zsh and related setup" ;;
    20-omarchy-shell.sh) echo "Keep Bash and Starship while adding theme-aware ble.sh" ;;
    30-cli-tools.sh) echo "Terminal toolbelt including utilities like yazi and tailscale" ;;
    30-omarchy-terminal.sh) echo "Select themed Kitty and verify Yazi image-preview support" ;;
    40-python.sh) echo "Python tooling and pip-based helpers" ;;
    40-omarchy-tailscale.sh) echo "Install and start Tailscale with separately gated login" ;;
    45-editors.sh) echo "Editors such as Neovim and related packages" ;;
    50-gui.sh) echo "Xorg, i3, polybar, kitty, themes, and desktop tools" ;;
    56-pvetui.sh) echo "Pinned pvetui .deb install for Proxmox-oriented machines" ;;
    56-omarchy-pvetui.sh) echo "Install pvetui from the AUR on Proxmox-oriented machines" ;;
    60-chezmoi.sh) echo "Install and initialize chezmoi using the configured dotfiles repo" ;;
    60-omarchy-chezmoi.sh) echo "Install chezmoi and optionally apply the configured dotfiles repo" ;;
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
10-omarchy-packages.sh
20-shell.sh
20-omarchy-shell.sh
30-cli-tools.sh
30-omarchy-terminal.sh
40-python.sh
40-omarchy-tailscale.sh
45-editors.sh
50-gui.sh
56-pvetui.sh
56-omarchy-pvetui.sh
60-chezmoi.sh
60-omarchy-chezmoi.sh
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
  if [[ "$PLATFORM" == "omarchy" ]]; then
    printf '  %s1)%s gui          %sAdd selected tools while preserving the Omarchy desktop%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
    printf '  %s2)%s cherry-pick  %sRun selected Omarchy-compatible components on demand%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  else
    printf '  %s1)%s headless     %sTerminal-first setup for servers, VMs, and minimal systems%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
    printf '  %s2)%s gui          %sHeadless setup plus Xorg, i3, kitty, polybar, and friends%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
    printf '  %s3)%s cherry-pick  %sRun selected bootstrap components on demand%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  fi
  printf '\n'
}

prompt_profile() {
  if [[ -n "$PROFILE" ]]; then
    return 0
  fi

  if [[ "$ASSUME_YES" == "true" ]]; then
    if [[ "$PLATFORM" == "omarchy" ]]; then
      PROFILE="gui"
    else
      PROFILE="headless"
    fi
    return 0
  fi

  local choice
  while true; do
    render_profile_menu
    if [[ "$PLATFORM" == "omarchy" ]]; then
      read -r -p "Choice [1/2]: " choice
      case "${choice:-1}" in
        1) PROFILE="gui"; break ;;
        2) PROFILE="cherry-pick"; break ;;
        *) warn "Invalid choice, please select 1 or 2." ;;
      esac
    else
      read -r -p "Choice [1/2/3]: " choice
      case "${choice:-1}" in
        1) PROFILE="headless"; break ;;
        2) PROFILE="gui"; break ;;
        3) PROFILE="cherry-pick"; break ;;
        *) warn "Invalid choice, please select 1, 2, or 3." ;;
      esac
    fi
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --platform)
        PLATFORM_REQUESTED="$2"
        shift 2
        ;;
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
      --apply-chezmoi)
        APPLY_CHEZMOI="true"
        APPLY_CHEZMOI_CHOICE_SET="true"
        WITH_CHEZMOI="true"
        CHEZMOI_CHOICE_SET="true"
        shift
        ;;
      --without-apply-chezmoi)
        APPLY_CHEZMOI="false"
        APPLY_CHEZMOI_CHOICE_SET="true"
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
      --tailscale-up)
        TAILSCALE_UP="true"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
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

  if [[ "$APPLY_CHEZMOI" == "true" ]]; then
    WITH_CHEZMOI="true"
    CHEZMOI_CHOICE_SET="true"
  fi

  if [[ "$PLATFORM_REQUESTED" != "auto" && "$PLATFORM_REQUESTED" != "debian" && "$PLATFORM_REQUESTED" != "omarchy" ]]; then
    fail "Invalid platform: $PLATFORM_REQUESTED"
    echo "Expected one of: auto, debian, omarchy"
    exit 1
  fi

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
  local command=()

  printf '\n%s[%s/%s]%s %s%s%s\n' "$C_DIM" "$current" "$TOTAL_STEPS" "$C_RESET" "$C_BOLD" "$title" "$C_RESET"
  draw_rule

  case "$script" in
    00-preflight.sh)
      command=(bash "$SCRIPTS_DIR/$script" "$PLATFORM" "$PROFILE")
      ;;
    05-hostname.sh|30-cli-tools.sh)
      command=(bash "$SCRIPTS_DIR/$script" "$ASSUME_YES")
      ;;
    15-keyboard.sh)
      command=(bash "$SCRIPTS_DIR/$script" "$PLATFORM")
      ;;
    40-omarchy-tailscale.sh)
      command=(bash "$SCRIPTS_DIR/$script" "$ASSUME_YES" "$TAILSCALE_UP")
      ;;
    60-chezmoi.sh)
      command=(bash "$SCRIPTS_DIR/$script" "$DOTFILES_REPO")
      ;;
    60-omarchy-chezmoi.sh)
      command=(bash "$SCRIPTS_DIR/$script" "$DOTFILES_REPO" "$APPLY_CHEZMOI")
      ;;
    70-postflight.sh)
      command=(bash "$SCRIPTS_DIR/$script" "$PLATFORM" "$PROFILE" "$WITH_CHEZMOI" "$WITH_PVETUI" "$APPLY_CHEZMOI")
      ;;
    *)
      command=(bash "$SCRIPTS_DIR/$script")
      ;;
  esac

  # GitHub issue #4: plan-only mode renders the exact component invocation and
  # returns before any platform script can mutate the host.
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '%sWould run:%s' "$C_DIM" "$C_RESET"
    printf ' %q' "${command[@]}"
    printf '\n'
    success "$title planned"
    return 0
  fi

  "${command[@]}"

  success "$title complete"
}

get_all_component_files() {
  local file
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    if is_component_script "$file"; then
      echo "$file"
    fi
  done < <(list_bootstrap_script_files)
}

get_component_files() {
  local file
  while IFS= read -r file; do
    if component_supports_platform "$file" "$PLATFORM"; then
      echo "$file"
    fi
  done < <(get_all_component_files)
}

build_profile_components() {
  local file
  while IFS= read -r file; do
    case "$file" in
      50-gui.sh) [[ "$PROFILE" == "gui" ]] && echo "$file" ;;
      56-pvetui.sh) [[ "$WITH_PVETUI" == "true" ]] && echo "$file" ;;
      60-chezmoi.sh) [[ "$WITH_CHEZMOI" == "true" ]] && echo "$file" ;;
      56-omarchy-pvetui.sh) [[ "$WITH_PVETUI" == "true" ]] && echo "$file" ;;
      60-omarchy-chezmoi.sh) [[ "$WITH_CHEZMOI" == "true" ]] && echo "$file" ;;
      *) echo "$file" ;;
    esac
  done < <(get_component_files)
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

    if [[ "$normalized" == *pvetui* && ( "$file" == "56-pvetui.sh" || "$file" == "56-omarchy-pvetui.sh" ) ]]; then
      echo "$file"
      return 0
    fi
    if [[ "$normalized" == *chezmoi* && ( "$file" == "60-chezmoi.sh" || "$file" == "60-omarchy-chezmoi.sh" ) ]]; then
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

  if [[ ${#available_components[@]} -eq 0 && -z "$COMPONENTS_RAW" ]]; then
    fail "No selectable bootstrap components were found"
    exit 1
  fi

  CHERRY_PICK_FILES=()

  local raw_input token resolved
  local all_components=()
  mapfile -t all_components < <(get_all_component_files)

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
    elif resolved="$(resolve_component_token "$token" "${all_components[@]}")"; then
      fail "Component '$resolved' is not available for platform '$PLATFORM'"
      exit 1
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
  resolve_platform

  export TERM="${TERM:-xterm-256color}"

  prepare_scripts_dir

  print_banner
  prompt_profile
  validate_platform_profile

  if [[ "$PROFILE" == "cherry-pick" ]]; then
    select_cherry_pick_components
    WITH_CHEZMOI="false"
    WITH_PVETUI="false"

    local selected
    for selected in "${CHERRY_PICK_FILES[@]}"; do
      [[ "$selected" == "60-chezmoi.sh" ]] && WITH_CHEZMOI="true"
      [[ "$selected" == "60-omarchy-chezmoi.sh" ]] && WITH_CHEZMOI="true"
      [[ "$selected" == "56-pvetui.sh" ]] && WITH_PVETUI="true"
      [[ "$selected" == "56-omarchy-pvetui.sh" ]] && WITH_PVETUI="true"
    done

    if [[ "$PLATFORM" == "debian" && "$WITH_CHEZMOI" == "true" ]]; then
      APPLY_CHEZMOI="true"
    fi

    TOTAL_STEPS=$((2 + ${#CHERRY_PICK_FILES[@]}))

    log "Bootstrap plan"
    echo "Platform     : $PLATFORM"
    echo "Profile      : $PROFILE"
    echo "chezmoi      : $WITH_CHEZMOI"
    echo "chezmoi apply: $APPLY_CHEZMOI"
    echo "pvetui       : $WITH_PVETUI"
    echo "tailscale up : $TAILSCALE_UP"
    echo "dry run      : $DRY_RUN"
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

  if [[ "$PLATFORM" == "debian" && "$CHEZMOI_CHOICE_SET" != "true" ]]; then
    if prompt_yes_no "Install and initialize chezmoi as part of bootstrap?" y; then
      WITH_CHEZMOI="true"
    else
      WITH_CHEZMOI="false"
    fi
  fi

  if [[ "$PLATFORM" == "omarchy" && "$CHEZMOI_CHOICE_SET" != "true" && "$ASSUME_YES" != "true" ]]; then
    if prompt_yes_no "Install chezmoi on Omarchy?" n; then
      WITH_CHEZMOI="true"
    fi
  fi

  if [[ "$PLATFORM" == "omarchy" && "$WITH_CHEZMOI" == "true" && "$APPLY_CHEZMOI_CHOICE_SET" != "true" && "$ASSUME_YES" != "true" ]]; then
    if prompt_yes_no "Initialize and apply $DOTFILES_REPO now?" n; then
      APPLY_CHEZMOI="true"
    fi
  fi

  if [[ "$PLATFORM" == "debian" && "$PVETUI_CHOICE_SET" != "true" ]]; then
    if prompt_yes_no "Install pvetui as an optional Proxmox helper?" n; then
      WITH_PVETUI="true"
    else
      WITH_PVETUI="false"
    fi
  fi

  if [[ "$PLATFORM" == "omarchy" && "$PVETUI_CHOICE_SET" != "true" && "$ASSUME_YES" != "true" ]]; then
    if prompt_yes_no "Install pvetui from the AUR?" n; then
      WITH_PVETUI="true"
    fi
  fi

  if [[ "$PLATFORM" == "debian" && "$WITH_CHEZMOI" == "true" ]]; then
    APPLY_CHEZMOI="true"
  fi

  local profile_components=()
  mapfile -t profile_components < <(build_profile_components)
  TOTAL_STEPS=$((2 + ${#profile_components[@]}))

  log "Bootstrap plan"
  echo "Platform     : $PLATFORM"
  echo "Profile      : $PROFILE"
  echo "chezmoi      : $WITH_CHEZMOI"
  echo "chezmoi apply: $APPLY_CHEZMOI"
  echo "pvetui       : $WITH_PVETUI"
  echo "tailscale up : $TAILSCALE_UP"
  echo "dry run      : $DRY_RUN"
  echo "dotfiles repo: $DOTFILES_REPO"

  run_step 1 "Preflight checks" 00-preflight.sh

  local step=2
  local selected
  for selected in "${profile_components[@]}"; do
    run_step "$step" "$(component_title "$selected")" "$selected"
    step=$((step + 1))
  done

  run_step "$step" "Postflight summary" 70-postflight.sh

  printf '\n%sBootstrap complete.%s\n' "$C_GREEN$C_BOLD" "$C_RESET"
}

if [[ "${BOOTSTRAP_TEST_MODE:-false}" != "true" ]]; then
  main "$@"
fi
