#!/usr/bin/env bash
# ==============================================================================
# install.sh — Production Installer for Hooky Ergonomic Theme
# https://github.com/seren/hooky
#
# Operations:
# 1. Installs canonical theme package to ~/.config/omarchy/themes/hooky/
# 2. Deploys Herdr dynamic theming hook to ~/.config/omarchy/hooks/theme-set.d/herdr.sh
# 3. Validates and patches Kitty font compositing (text_composition_strategy platform)
# 4. Compiles and activates theme via omarchy theme set hooky
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

THEME_SRC="$REPO_DIR/theme"
TARGET_DIR="${OMARCHY_THEMES_PATH:-$HOME/.config/omarchy/themes}/hooky"
HOOKS_DIR="${OMARCHY_HOOKS_PATH:-$HOME/.config/omarchy/hooks/theme-set.d}"
KITTY_CONF="${KITTY_CONF:-$HOME/.config/kitty/kitty.conf}"

DRY_RUN=0
NO_APPLY=0
HOOK_ONLY=0

# Formatting
BOLD="\033[1m"
GREEN="\033[32m"
AMBER="\033[33m"
BLUE="\033[34m"
RED="\033[31m"
DIM="\033[2m"
RESET="\033[0m"

log_info()  { echo -e "${BLUE}[INFO]${RESET} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn()  { echo -e "${AMBER}[WARN]${RESET} $*"; }
log_err()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -d, --dry-run     Show planned actions without modifying filesystem
  -n, --no-apply    Install theme files and hooks without activating via omarchy theme set
  --hook-only       Only install the Herdr theme-set synchronization hook
  -h, --help        Display this help message
EOF
}

while (( $# > 0 )); do
  case "$1" in
    -d|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -n|--no-apply)
      NO_APPLY=1
      shift
      ;;
    --hook-only)
      HOOK_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

echo -e "\n${BOLD}${AMBER}Installing Hooky Ergonomic Theme${RESET}"
echo -e "${DIM}Repository: $REPO_DIR${RESET}\n"

# ------------------------------------------------------------------------------
# 1. Install Herdr sync hook
# ------------------------------------------------------------------------------
install_herdr_hook() {
  log_info "Deploying Herdr synchronization hook to $HOOKS_DIR/herdr.sh..."
  if (( DRY_RUN )); then
    log_info "[DRY-RUN] Would create $HOOKS_DIR and copy $SCRIPT_DIR/sync-herdr.sh"
    return 0
  fi

  mkdir -p "$HOOKS_DIR"
  cp -f "$SCRIPT_DIR/sync-herdr.sh" "$HOOKS_DIR/herdr.sh"
  chmod +x "$HOOKS_DIR/herdr.sh"
  log_ok "Herdr hook installed and made executable."

  # Immediately synchronize Herdr configuration if config exists
  local herdr_cfg="${HERDR_CONFIG:-$HOME/.config/herdr/config.toml}"
  if [[ -f "$herdr_cfg" ]]; then
    log_info "Synchronizing Herdr configuration..."
    "$HOOKS_DIR/herdr.sh" || log_warn "Initial Herdr synchronization returned non-zero status."
    log_ok "Herdr configuration synchronized."
  fi
}

if (( HOOK_ONLY )); then
  install_herdr_hook
  echo -e "\n${GREEN}${BOLD}Hook installation complete.${RESET}\n"
  exit 0
fi

# ------------------------------------------------------------------------------
# 2. Install Omarchy theme package
# ------------------------------------------------------------------------------
install_theme_package() {
  if [[ ! -d "$THEME_SRC" ]]; then
    log_err "Source theme directory not found at $THEME_SRC"
    exit 1
  fi

  log_info "Installing Hooky theme package to $TARGET_DIR..."
  if (( DRY_RUN )); then
    log_info "[DRY-RUN] Would create $TARGET_DIR and copy theme files"
    return 0
  fi

  mkdir -p "$TARGET_DIR"
  cp -rf "$THEME_SRC"/* "$TARGET_DIR"/
  log_ok "Copied colors.toml, shell.toml, obsidian.css, icons.theme, backgrounds, and preview."
}

# ------------------------------------------------------------------------------
# 3. Patch Kitty font compositing
# ------------------------------------------------------------------------------
patch_kitty_compositing() {
  if [[ ! -f "$KITTY_CONF" ]]; then
    if command -v kitty >/dev/null 2>&1 || [[ -d "$(dirname "$KITTY_CONF")" ]]; then
      log_info "Initializing Kitty configuration at $KITTY_CONF with platform compositing..."
      if (( DRY_RUN )); then
        log_info "[DRY-RUN] Would create $KITTY_CONF with text_composition_strategy platform"
        return 0
      fi
      mkdir -p "$(dirname "$KITTY_CONF")"
      cat <<EOF > "$KITTY_CONF"
# Ergonomic typography: eliminate dark-mode alpha stroke erosion
text_composition_strategy platform
EOF
      log_ok "Created $KITTY_CONF with 'text_composition_strategy platform'."
      return 0
    else
      log_warn "Kitty configuration not found at $KITTY_CONF; skipping compositing patch."
      return 0
    fi
  fi

  log_info "Inspecting Kitty font compositing in $KITTY_CONF..."

  if grep -q "^[[:space:]]*text_composition_strategy[[:space:]]\+platform" "$KITTY_CONF"; then
    log_ok "Kitty already configured with 'text_composition_strategy platform'."
    return 0
  fi

  if (( DRY_RUN )); then
    log_info "[DRY-RUN] Would update text_composition_strategy to 'platform' in $KITTY_CONF"
    return 0
  fi

  # Backup
  local backup="${KITTY_CONF}.bak-$(date +%Y%m%d%H%M%S)"
  cp -a "$KITTY_CONF" "$backup"
  log_info "Created backup: $backup"

  if grep -q "^[[:space:]]*text_composition_strategy" "$KITTY_CONF"; then
    sed -i 's/^[[:space:]]*text_composition_strategy.*/text_composition_strategy platform/' "$KITTY_CONF"
    log_ok "Updated text_composition_strategy to 'platform'."
  else
    cat <<EOF >> "$KITTY_CONF"

# Ergonomic typography: eliminate dark-mode alpha stroke erosion
text_composition_strategy platform
EOF
    log_ok "Appended 'text_composition_strategy platform' to $KITTY_CONF."
  fi
}

# ------------------------------------------------------------------------------
# 4. Activate theme via omarchy
# ------------------------------------------------------------------------------
activate_theme() {
  if (( NO_APPLY )); then
    log_info "Skipping theme activation (--no-apply specified)."
    return 0
  fi

  if ! command -v omarchy >/dev/null 2>&1; then
    log_warn "'omarchy' binary not found on PATH. Manual activation required:"
    echo "  omarchy theme set hooky"
    return 0
  fi

  log_info "Activating theme via 'omarchy theme set hooky'..."
  if (( DRY_RUN )); then
    log_info "[DRY-RUN] Would run: omarchy theme set hooky"
    return 0
  fi

  omarchy theme set hooky
  log_ok "Theme successfully set to Hooky."
}

# Run pipeline
install_theme_package
install_herdr_hook
patch_kitty_compositing
activate_theme

echo -e "\n${BOLD}${GREEN}Installation and configuration complete!${RESET}\n"
