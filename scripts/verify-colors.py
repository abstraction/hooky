#!/usr/bin/env python3
"""
verify-colors.py — Ergonomic & Colorimetric Verification Engine for Hooky
https://github.com/abstraction/hooky

Grounded in:
Advanced-Ergonomic-Color-Systems-and-Dynamic-Theming-Architecture-for-Omarchy-Li.md

Evaluates:
- Exact OKLCH Coordinates (L, C, H) via Oklab perceptual color space
- APCA-W3 v0.98G Lightness Contrast (Lc) scores
- WCAG 2.1 Relative Luminance & Contrast Ratios
- Ergonomic guardrails (Halation floor, LCA lag, Z-index elevation, glare suppression)
"""

import argparse
import json
import math
import os
import sys
from typing import Dict, List, Optional, Tuple


def hex_to_rgb(hex_str: str) -> Tuple[int, int, int]:
    """Parse #RRGGBB hex string to 0-255 RGB integers."""
    clean = hex_str.strip().lstrip("#")
    if len(clean) == 3:
        clean = "".join(c * 2 for c in clean)
    if len(clean) != 6:
        raise ValueError(f"Invalid hex color: {hex_str}")
    return int(clean[0:2], 16), int(clean[2:4], 16), int(clean[4:6], 16)


def srgb_to_linear(c_byte: int) -> float:
    """Convert 8-bit sRGB channel to linear float [0.0, 1.0]."""
    c = c_byte / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb_to_linear(r: int, g: int, b: int) -> Tuple[float, float, float]:
    return srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)


def cie_relative_luminance(r: int, g: int, b: int) -> float:
    """Compute CIE 1931 relative luminance Y from sRGB channels."""
    r_lin, g_lin, b_lin = rgb_to_linear(r, g, b)
    return 0.2126729 * r_lin + 0.7151522 * g_lin + 0.0721750 * b_lin


def rgb_to_oklch(r: int, g: int, b: int) -> Tuple[float, float, float]:
    """
    Convert sRGB (0-255) to OKLCH (Lightness [0..1], Chroma [0..], Hue [0..360)).
    Uses the Björn Ottosson Oklab / OKLCH transformation matrix.
    """
    r_lin, g_lin, b_lin = rgb_to_linear(r, g, b)

    # Linear sRGB to LMS
    l = 0.4122214708 * r_lin + 0.5363325363 * g_lin + 0.0514459929 * b_lin
    m = 0.2119034982 * r_lin + 0.6806995451 * g_lin + 0.1073969566 * b_lin
    s = 0.0883024619 * r_lin + 0.2817188376 * g_lin + 0.6299787005 * b_lin

    # Non-linear cubic root
    l_ = math.pow(l, 1 / 3) if l > 0 else 0.0
    m_ = math.pow(m, 1 / 3) if m > 0 else 0.0
    s_ = math.pow(s, 1 / 3) if s > 0 else 0.0

    # LMS to Oklab (L, a, b)
    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    b_val = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

    # Oklab to OKLCH
    C = math.sqrt(a * a + b_val * b_val)
    H = math.degrees(math.atan2(b_val, a)) % 360.0

    return L, C, H


def apca_w3_contrast(txt_hex: str, bg_hex: str) -> float:
    """
    Compute APCA-W3 v0.98G Lightness Contrast (Lc) score.
    Returns positive value for Light text on Dark background (WoB).
    """
    r_txt, g_txt, b_txt = hex_to_rgb(txt_hex)
    r_bg, g_bg, b_bg = hex_to_rgb(bg_hex)

    Y_txt = cie_relative_luminance(r_txt, g_txt, b_txt)
    Y_bg = cie_relative_luminance(r_bg, g_bg, b_bg)

    # Clamp
    Y_txt = max(0.0, min(1.1, Y_txt))
    Y_bg = max(0.0, min(1.1, Y_bg))

    # APCA 0.98G Constants
    normBG = 0.56
    normTXT = 0.57
    revBG = 0.62
    revTXT = 0.65
    blkThrs = 0.022
    blkClmp = 1.414
    scaleBoW = 1.14
    scaleWoB = 1.14
    loBoWoffset = 0.027
    loWoBoffset = 0.027
    deltaYmin = 0.0005
    loClip = 0.1

    # Soft black clamping
    Y_txt_c = Y_txt if Y_txt > blkThrs else Y_txt + math.pow(blkThrs - Y_txt, blkClmp)
    Y_bg_c = Y_bg if Y_bg > blkThrs else Y_bg + math.pow(blkThrs - Y_bg, blkClmp)

    if abs(Y_bg_c - Y_txt_c) < deltaYmin:
        return 0.0

    if Y_bg_c > Y_txt_c:
        # Dark text on Light background (BoW)
        Sapc = (math.pow(Y_bg_c, normBG) - math.pow(Y_txt_c, normTXT)) * scaleBoW
        contrast = 0.0 if Sapc < loClip else (Sapc - loBoWoffset) * 100.0
    else:
        # Light text on Dark background (WoB)
        Sapc = (math.pow(Y_bg_c, revBG) - math.pow(Y_txt_c, revTXT)) * scaleWoB
        contrast = 0.0 if abs(Sapc) < loClip else (abs(Sapc) - loWoBoffset) * 100.0

    return abs(contrast)


def wcag_contrast_ratio(txt_hex: str, bg_hex: str) -> float:
    """Compute legacy WCAG 2.1 contrast ratio (1.0 to 21.0)."""
    r_txt, g_txt, b_txt = hex_to_rgb(txt_hex)
    r_bg, g_bg, b_bg = hex_to_rgb(bg_hex)
    y1 = cie_relative_luminance(r_txt, g_txt, b_txt)
    y2 = cie_relative_luminance(r_bg, g_bg, b_bg)
    lighter = max(y1, y2)
    darker = min(y1, y2)
    return (lighter + 0.05) / (darker + 0.05)


def parse_colors_toml(path: str) -> Dict[str, str]:
    """Parse colors.toml file into key-value hex dictionary using tomllib with fallback."""
    colors = {}
    try:
        import tomllib
        with open(path, "rb") as f:
            data = tomllib.load(f)
            for k, v in data.items():
                if isinstance(v, str) and v.startswith("#") and len(v) in (4, 7):
                    colors[k] = v
        if colors:
            return colors
    except Exception:
        pass

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                k = k.strip().strip('"').strip("'")
                v = v.strip()
                if (v.startswith('"') and '"' in v[1:]) or (v.startswith("'") and "'" in v[1:]):
                    quote_char = v[0]
                    v = v[1:].split(quote_char, 1)[0]
                else:
                    v = v.split("#", 1)[0].strip()
                if v.startswith("#") and len(v) in (4, 7):
                    colors[k] = v
    return colors


def evaluate_guardrails(colors: Dict[str, str]) -> List[Tuple[str, bool, str]]:
    """
    Evaluate physiological and mathematical guardrails from research paper:
    Returns list of (guardrail_name, passed, explanation).
    Fails explicitly if any required semantic token is missing.
    """
    results = []

    # 1. Background Halation Floor
    if "background" not in colors:
        results.append((
            "Halation Floor (Background L)",
            False,
            "Missing required token 'background' in colors.toml"
        ))
        bg_hex = None
        bg_l = 0.0
    else:
        bg_hex = colors["background"]
        bg_rgb = hex_to_rgb(bg_hex)
        bg_l, bg_c, bg_h = rgb_to_oklch(*bg_rgb)
        bg_pass = 0.15 <= bg_l <= 0.22
        results.append((
            "Halation Floor (Background L)",
            bg_pass,
            f"L = {bg_l:.4f} (target: 0.15 <= L <= 0.22, non-zero to suppress halation)"
        ))

    # 2. Stepped Elevation (+0.02 to +0.05 L)
    if "lighter_background" not in colors:
        results.append((
            "Z-Index Elevation (lighter_background)",
            False,
            "Missing required token 'lighter_background' in colors.toml"
        ))
    elif bg_hex is None:
        results.append((
            "Z-Index Elevation (lighter_background)",
            False,
            "Cannot evaluate elevation: missing base 'background' token"
        ))
    else:
        lighter_hex = colors["lighter_background"]
        lighter_l, _, _ = rgb_to_oklch(*hex_to_rgb(lighter_hex))
        delta_l = lighter_l - bg_l
        elev_pass = 0.020 <= delta_l <= 0.055
        results.append((
            "Z-Index Elevation (lighter_background)",
            elev_pass,
            f"ΔL = +{delta_l:.4f} (target: +0.020 <= ΔL <= +0.055, shadow-free depth)"
        ))

    # 3. Recessed Panels (dark_background)
    if "dark_background" not in colors:
        results.append((
            "Recessed Sidebar (dark_background)",
            False,
            "Missing required token 'dark_background' in colors.toml"
        ))
    elif bg_hex is None:
        results.append((
            "Recessed Sidebar (dark_background)",
            False,
            "Cannot evaluate recessed panels: missing base 'background' token"
        ))
    else:
        dark_hex = colors["dark_background"]
        dark_l, _, _ = rgb_to_oklch(*hex_to_rgb(dark_hex))
        recess_pass = dark_l <= bg_l and dark_l >= 0.12
        results.append((
            "Recessed Sidebar (dark_background)",
            recess_pass,
            f"L = {dark_l:.4f} <= base L ({bg_l:.4f}) and >= 0.12 floor"
        ))

    # 4. Foreground Readability & Warmth
    if "foreground" not in colors:
        results.append((
            "Primary Text Contrast & Warmth (foreground)",
            False,
            "Missing required token 'foreground' in colors.toml"
        ))
    elif bg_hex is None:
        results.append((
            "Primary Text Contrast & Warmth (foreground)",
            False,
            "Cannot evaluate text contrast: missing base 'background' token"
        ))
    else:
        fg_hex = colors["foreground"]
        fg_l, fg_c, fg_h = rgb_to_oklch(*hex_to_rgb(fg_hex))
        fg_apca = apca_w3_contrast(fg_hex, bg_hex)
        fg_pass = fg_apca >= 65.0 and fg_c <= 0.035
        results.append((
            "Primary Text Contrast & Warmth (foreground)",
            fg_pass,
            f"APCA Lc = {fg_apca:.1f} (target >= 65.0 clamped, ~74.5 nominal), Chroma C = {fg_c:.4f} (target <= 0.035)"
        ))

    # 5. Glare Suppression (bright_foreground == foreground)
    if "bright_foreground" not in colors or "foreground" not in colors:
        results.append((
            "Selection Glare Neutralization (bright_fg)",
            False,
            "Missing required token 'bright_foreground' or 'foreground' in colors.toml"
        ))
    else:
        bright_fg_hex = colors["bright_foreground"]
        fg_hex = colors["foreground"]
        glare_pass = bright_fg_hex.lower() == fg_hex.lower()
        results.append((
            "Selection Glare Neutralization (bright_fg)",
            glare_pass,
            f"bright_foreground ({bright_fg_hex}) matches foreground ({fg_hex}) to eliminate stark flashes"
            if glare_pass else
            f"bright_foreground ({bright_fg_hex}) differs from foreground ({fg_hex}), inducing selection glare"
        ))

    # 6. Accommodative Lag & Primary Accent
    if "accent" not in colors:
        results.append((
            "Accommodative Focus Lag (accent Hue)",
            False,
            "Missing required token 'accent' in colors.toml"
        ))
    else:
        accent_hex = colors["accent"]
        accent_l, accent_c, accent_h = rgb_to_oklch(*hex_to_rgb(accent_hex))
        accent_pass = 20.0 <= accent_h <= 65.0
        results.append((
            "Accommodative Focus Lag (accent Hue)",
            accent_pass,
            f"Hue H = {accent_h:.1f}° (target 20° <= H <= 65° warm terracotta/amber for 0.18 D lag)"
        ))

    # 7. Blue Light Defocus (LCA Neutralization)
    if "blue" not in colors:
        results.append((
            "Longitudinal Chromatic Aberration (blue)",
            False,
            "Missing required token 'blue' in colors.toml"
        ))
    else:
        blue_hex = colors["blue"]
        blue_l, blue_c, blue_h = rgb_to_oklch(*hex_to_rgb(blue_hex))
        blue_cyan_shift = 180.0 <= blue_h <= 225.0
        blue_low_chroma = blue_c < 0.10
        blue_high_l = blue_l > 0.70
        blue_pass = blue_cyan_shift or blue_low_chroma or blue_high_l
        results.append((
            "Longitudinal Chromatic Aberration (blue)",
            blue_pass,
            f"H = {blue_h:.1f}°, C = {blue_c:.4f}, L = {blue_l:.4f} (Neutralizes 0.61 D defocus)"
        ))

    # 8. Muted Secondary Text Contrast
    if "muted" not in colors:
        results.append((
            "Muted Secondary Readability (muted)",
            False,
            "Missing required token 'muted' in colors.toml"
        ))
    elif bg_hex is None:
        results.append((
            "Muted Secondary Readability (muted)",
            False,
            "Cannot evaluate secondary text: missing base 'background' token"
        ))
    else:
        muted_hex = colors["muted"]
        muted_apca = apca_w3_contrast(muted_hex, bg_hex)
        muted_pass = muted_apca >= 35.0
        results.append((
            "Muted Secondary Readability (muted)",
            muted_pass,
            f"APCA Lc = {muted_apca:.1f} (target >= 35.0 for comments & line numbers)"
        ))

    return results


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify Hooky theme colorimetric guardrails")
    parser.add_argument("--file", "-f", help="Path to colors.toml to analyze", default=None)
    parser.add_argument("--json", action="store_true", help="Output machine-readable JSON results")
    parser.add_argument("--verbose", "-v", action="store_true", help="Print extended color matrix")
    args = parser.parse_args()

    # Discover colors.toml
    target_path = args.file
    if not target_path:
        default_candidates = [
            os.path.join(os.path.dirname(__file__), "..", "theme", "colors.toml"),
            os.path.expanduser("~/.config/omarchy/themes/hooky/colors.toml"),
            os.path.expanduser("~/.config/omarchy/themes/terra/colors.toml"),
            os.path.expanduser("~/.local/state/omarchy/current/theme/colors.toml"),
        ]
        for candidate in default_candidates:
            if os.path.isfile(candidate):
                target_path = candidate
                break

    if not target_path or not os.path.isfile(target_path):
        sys.stderr.write("Error: Could not locate colors.toml. Specify path via --file <path>.\n")
        return 2

    colors = parse_colors_toml(target_path)
    if not colors:
        sys.stderr.write(f"Error: No valid colors found in {target_path}\n")
        return 2

    bg_hex = colors.get("background", "#191716")
    guardrails = evaluate_guardrails(colors)
    all_passed = all(passed for _, passed, _ in guardrails)

    if args.json:
        out = {
            "file": os.path.abspath(target_path),
            "status": "PASS" if all_passed else "FAIL",
            "guardrails": [
                {"name": name, "passed": passed, "details": details}
                for name, passed, details in guardrails
            ],
            "tokens": {}
        }
        for token, hex_val in colors.items():
            r, g, b = hex_to_rgb(hex_val)
            l, c, h = rgb_to_oklch(r, g, b)
            y = cie_relative_luminance(r, g, b)
            apca = apca_w3_contrast(hex_val, bg_hex)
            wcag = wcag_contrast_ratio(hex_val, bg_hex)
            out["tokens"][token] = {
                "hex": hex_val,
                "rgb": [r, g, b],
                "oklch": {"l": round(l, 4), "c": round(c, 4), "h": round(h, 1)},
                "cie_y": round(y, 4),
                "apca_lc": round(apca, 1),
                "wcag_ratio": round(wcag, 2)
            }
        print(json.dumps(out, indent=2))
        return 0 if all_passed else 1

    # Formatted terminal output
    cyan = "\033[36m"
    amber = "\033[33m"
    green = "\033[32m"
    red = "\033[31m"
    bold = "\033[1m"
    dim = "\033[2m"
    reset = "\033[0m"

    print(f"\n{bold}{amber}Hooky Colorimetric Verification Engine{reset}")
    print(f"{dim}Inspecting:{reset} {os.path.abspath(target_path)}\n")

    print(f"{bold}{'Token':<24} {'Hex':<9} {'OKLCH (L, C, H)':<24} {'APCA Lc':<9} {'WCAG 2.1':<8}{reset}")
    print("-" * 76)

    critical_tokens = [
        "background", "lighter_background", "dark_background", "selection",
        "foreground", "bright_foreground", "muted", "dark_foreground",
        "accent", "blue", "red", "yellow", "green", "cyan", "magenta"
    ]

    for token in critical_tokens:
        if token not in colors:
            continue
        hex_val = colors[token]
        r, g, b = hex_to_rgb(hex_val)
        l, c, h = rgb_to_oklch(r, g, b)
        apca = apca_w3_contrast(hex_val, bg_hex)
        wcag = wcag_contrast_ratio(hex_val, bg_hex)
        oklch_str = f"{l:.3f}, {c:.3f}, {h:5.1f}°"
        apca_str = f"{apca:5.1f}" if token != "background" else "  ---"
        wcag_str = f"{wcag:4.1f}:1" if token != "background" else " --- "
        print(f"{cyan}{token:<24}{reset} {hex_val:<9} {oklch_str:<24} {apca_str:<9} {wcag_str:<8}")

    print("\n" + "=" * 76)
    print(f"{bold}Physiological & Mathematical Guardrail Checks{reset}")
    print("=" * 76)

    for name, passed, details in guardrails:
        badge = f"{green}[PASS]{reset}" if passed else f"{red}[FAIL]{reset}"
        print(f"{badge} {bold}{name}{reset}\n       {dim}{details}{reset}")

    print("-" * 76)
    if all_passed:
        print(f"{bold}{green}All 8 ergonomic guardrails successfully verified. Theme is production-grade.{reset}\n")
        return 0
    else:
        print(f"{bold}{red}One or more ergonomic guardrails failed verification.{reset}\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
