#!/usr/bin/env bash
# ==============================================================================
# uninstall.sh — Clean Rollback Script for Hooky Theme
# https://github.com/abstraction/hooky
#
# Operations:
# 1. Removes ~/.config/omarchy/themes/hooky/
# 2. Removes ~/.config/omarchy/hooks/theme-set.d/herdr.sh
# 3. Optionally switches to a fallback theme (default: 'Tokyo Night' or custom)
# ==============================================================================

set -euo pipefail

TARGET_DIR="${OMARCHY_THEMES_PATH:-$HOME/.config/omarchy/themes}/hooky"
HOOK_FILE="${OMARCHY_HOOKS_PATH:-$HOME/.config/omarchy/hooks/theme-set.d}/herdr.sh"

DRY_RUN=0
FORCE=0
KEEP_HOOK=0
FALLBACK_THEME=""

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
  -f, --force              Remove files without interactive confirmation
  -d, --dry-run            Show actions without deleting files
  --keep-hook              Retain the Herdr theme-set synchronization hook
  --fallback <name>        Switch to specified theme after removal
  -h, --help               Display this help message
EOF
}

while (( $# > 0 )); do
  case "$1" in
    -f|--force)
      FORCE=1
      shift
      ;;
    -d|--dry-run)
      DRY_RUN=1
      shift
      ;;
    --keep-hook)
      KEEP_HOOK=1
      shift
      ;;
    --fallback)
      FALLBACK_THEME="${2:-}"
      shift 2
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

echo -e "\n${BOLD}${AMBER}Uninstalling Hooky Ergonomic Theme${RESET}\n"

# Check if Hooky is currently the active theme
CURRENT_THEME_FILE="$HOME/.local/state/omarchy/current/theme.name"
if [[ -f "$CURRENT_THEME_FILE" ]]; then
  ACTIVE_THEME=$(cat "$CURRENT_THEME_FILE" 2>/dev/null || true)
  if [[ "$ACTIVE_THEME" == "hooky" && -z "$FALLBACK_THEME" ]]; then
    log_warn "Hooky is currently the active desktop theme."
    log_warn "Recommend passing --fallback <theme> (e.g. --fallback tokyo-night) to prevent an unstyled desktop."
  fi
fi

# Interactive confirmation when not forced and not dry-run
if (( ! FORCE && ! DRY_RUN )); then
  if [[ -t 0 ]]; then
    read -r -p "Are you sure you want to uninstall Hooky theme and hooks? [y/N] " confirm
    case "$confirm" in
      [yY][eE][sS]|[yY]) ;;
      *)
        log_info "Uninstall aborted by user."
        exit 0
        ;;
    esac
  fi
fi

# 1. Switch to fallback theme BEFORE removing files to prevent broken desktop state
if [[ -n "$FALLBACK_THEME" ]]; then
  if command -v omarchy >/dev/null 2>&1; then
    log_info "Switching to fallback theme '$FALLBACK_THEME' prior to removal..."
    if (( DRY_RUN )); then
      log_info "[DRY-RUN] Would run: omarchy theme set \"$FALLBACK_THEME\""
    else
      omarchy theme set "$FALLBACK_THEME"
      log_ok "Switched theme to $FALLBACK_THEME."
    fi
  else
    log_warn "'omarchy' binary not found; cannot switch to fallback theme."
  fi
fi

# 2. Remove theme directory
if [[ -d "$TARGET_DIR" ]]; then
  log_info "Target theme directory found: $TARGET_DIR"
  if (( DRY_RUN )); then
    log_info "[DRY-RUN] Would remove directory $TARGET_DIR"
  else
    rm -rf "$TARGET_DIR"
    log_ok "Removed $TARGET_DIR"
  fi
else
  log_info "Theme directory not found at $TARGET_DIR; skipping."
fi

# 3. Remove Herdr hook
if (( ! KEEP_HOOK )); then
  if [[ -f "$HOOK_FILE" ]]; then
    log_info "Herdr hook found: $HOOK_FILE"
    if (( DRY_RUN )); then
      log_info "[DRY-RUN] Would remove hook $HOOK_FILE"
    else
      rm -f "$HOOK_FILE"
      log_ok "Removed Herdr sync hook from $HOOK_FILE"
    fi
  else
    log_info "Herdr hook not found at $HOOK_FILE; skipping."
  fi
else
  log_info "Retaining Herdr hook (--keep-hook specified)."
fi

echo -e "\n${BOLD}${GREEN}Uninstall complete.${RESET}\n"
