#!/usr/bin/env bash
# ==============================================================================
# sync-herdr.sh — Sync Omarchy / Hooky theme colors into Herdr config
# https://github.com/abstraction/hooky
#
# Can be run directly or placed into ~/.config/omarchy/hooks/theme-set.d/herdr.sh
# ==============================================================================

set -euo pipefail

HERDR_CONFIG="${HERDR_CONFIG:-$HOME/.config/herdr/config.toml}"

if [[ ! -f "$HERDR_CONFIG" ]]; then
  # If Herdr is not installed or configured, exit cleanly
  exit 0
fi

# Resolve color values via omarchy-theme-color if available, otherwise use Hooky defaults
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

# Update Herdr configuration with section-aware parser
python3 - "$HERDR_CONFIG" "$ACCENT" "$BG" "$DARK_BG" "$SELECTION" "$MUTED" <<'PYEOF'
import sys, re

config_path = sys.argv[1]
accent = sys.argv[2]
bg = sys.argv[3]
dark_bg = sys.argv[4]
selection = sys.argv[5]
muted = sys.argv[6]

custom_keys = {
    "panel_bg": bg,
    "sidebar_bg": dark_bg,
    "active_row_bg": selection,
    "surface_dim": muted,
    "selection_bg": selection,
    "accent": accent,
}

try:
    with open(config_path, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
except Exception:
    sys.exit(0)

new_lines = []
current_section = None
custom_keys_seen = set()
has_theme_custom_section = any(re.match(r"^\s*\[theme\.custom\]", l) for l in lines)
has_ui_section = any(re.match(r"^\s*\[ui\]", l) for l in lines)
ui_accent_seen = False

i = 0
while i < len(lines):
    line = lines[i]
    m = re.match(r"^\s*\[([^\]]+)\]", line)
    if m:
        if current_section == "theme.custom":
            for k, v in custom_keys.items():
                if k not in custom_keys_seen:
                    new_lines.append(f'{k} = "{v}"')
                    custom_keys_seen.add(k)
        elif current_section == "ui" and not ui_accent_seen:
            new_lines.append(f'accent = "{accent}"')
            ui_accent_seen = True

        current_section = m.group(1).strip()
        new_lines.append(line)
        i += 1
        continue

    if current_section == "theme.custom":
        km = re.match(r"^(\s*)([a-zA-Z0-9_]+)(\s*=.*)$", line)
        if km:
            indent, k = km.group(1), km.group(2)
            if k in custom_keys:
                new_lines.append(f'{indent}{k} = "{custom_keys[k]}"')
                custom_keys_seen.add(k)
                i += 1
                continue
    elif current_section == "ui":
        km = re.match(r"^(\s*)(accent)(\s*=.*)$", line)
        if km:
            indent = km.group(1)
            new_lines.append(f'{indent}accent = "{accent}"')
            ui_accent_seen = True
            i += 1
            continue

    new_lines.append(line)
    i += 1

if current_section == "theme.custom":
    for k, v in custom_keys.items():
        if k not in custom_keys_seen:
            new_lines.append(f'{k} = "{v}"')
            custom_keys_seen.add(k)
elif current_section == "ui" and not ui_accent_seen:
    new_lines.append(f'accent = "{accent}"')
    ui_accent_seen = True

if not has_theme_custom_section:
    if new_lines and new_lines[-1].strip() != "":
        new_lines.append("")
    new_lines.append("[theme.custom]")
    for k, v in custom_keys.items():
        new_lines.append(f'{k} = "{v}"')

if not has_ui_section:
    if new_lines and new_lines[-1].strip() != "":
        new_lines.append("")
    new_lines.append("[ui]")
    new_lines.append(f'accent = "{accent}"')

with open(config_path, "w", encoding="utf-8") as f:
    f.write("\n".join(new_lines) + "\n")
PYEOF

# Reload herdr server if running
if command -v herdr >/dev/null 2>&1; then
  herdr server reload-config >/dev/null 2>&1 || true
fi
