#!/usr/bin/env bash
# ==============================================================================
# sync-herdr.sh — Sync Omarchy / Terra theme colors into Herdr config
# https://github.com/seren/hooky
#
# Can be run directly or placed into ~/.config/omarchy/hooks/theme-set.d/herdr.sh
# ==============================================================================

set -euo pipefail

HERDR_CONFIG="${HERDR_CONFIG:-$HOME/.config/herdr/config.toml}"

if [[ ! -f "$HERDR_CONFIG" ]]; then
  # If Herdr is not installed or configured, exit cleanly
  exit 0
fi

# Resolve color values via omarchy-theme-color if available, otherwise use Terra defaults
get_color() {
  local key="$1"
  local fallback="$2"
  if command -v omarchy-theme-color >/dev/null 2>&1; then
    omarchy-theme-color "$key" "$fallback" 2>/dev/null || echo "$fallback"
  else
    echo "$fallback"
  fi
}

ACCENT=$(get_color accent "#e59458")
BG=$(get_color background "#191716")
DARK_BG=$(get_color dark_background "#141312")
SELECTION=$(get_color selection "#3a3430")
MUTED=$(get_color muted "#9b948a")

# Ensure [theme.custom] section exists
if ! grep -q '^\[theme\.custom\]' "$HERDR_CONFIG"; then
  cat <<EOF >> "$HERDR_CONFIG"

[theme.custom]
panel_bg = "$BG"
sidebar_bg = "$DARK_BG"
active_row_bg = "$SELECTION"
surface_dim = "$MUTED"
selection_bg = "$SELECTION"
accent = "$ACCENT"
EOF
else
  # Replace existing keys or append missing ones
  for pair in "panel_bg:$BG" "sidebar_bg:$DARK_BG" "active_row_bg:$SELECTION" "surface_dim:$MUTED" "selection_bg:$SELECTION" "accent:$ACCENT"; do
    key="${pair%%:*}"
    val="${pair#*:}"
    if grep -q "^${key} = " "$HERDR_CONFIG"; then
      sed -i "s|^${key} = .*|${key} = \"${val}\"|" "$HERDR_CONFIG"
    else
      # Append under [theme.custom]
      sed -i "/^\[theme\.custom\]/a ${key} = \"${val}\"" "$HERDR_CONFIG"
    fi
  done
fi

# Also ensure top-level ui accent matches if present
if grep -q '^\[ui\]' "$HERDR_CONFIG"; then
  if grep -q '^accent = ' "$HERDR_CONFIG"; then
    sed -i "s|^accent = .*|accent = \"$ACCENT\"|" "$HERDR_CONFIG"
  fi
fi

# Reload herdr server if running
if command -v herdr >/dev/null 2>&1; then
  herdr server reload-config >/dev/null 2>&1 || true
fi
