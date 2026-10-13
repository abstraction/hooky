#!/usr/bin/env python3
"""
test_theme.py — Automated verification test suite for Terra (Hooky) theme.
Tests color guardrails, script plumbing, standalone config syntax, and error handling.
"""

import json
import os
import subprocess
import sys
import tempfile
import tomllib
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SCRIPTS_DIR = os.path.join(REPO_ROOT, "scripts")
THEME_DIR = os.path.join(REPO_ROOT, "theme")
STANDALONE_DIR = os.path.join(REPO_ROOT, "standalone")


class TestColorVerificationEngine(unittest.TestCase):
    def setUp(self):
        self.verify_script = os.path.join(SCRIPTS_DIR, "verify-colors.py")
        self.colors_toml = os.path.join(THEME_DIR, "colors.toml")

    def test_canonical_theme_passes(self):
        """Canonical theme/colors.toml must pass all 8 guardrails with exit code 0."""
        res = subprocess.run(
            [sys.executable, self.verify_script, "--file", self.colors_toml],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, f"Engine failed on canonical theme: {res.stderr}\n{res.stdout}")
        self.assertIn("All 8 ergonomic guardrails successfully verified", res.stdout)

    def test_json_output(self):
        """--json flag must return valid JSON with status PASS and 8 guardrails."""
        res = subprocess.run(
            [sys.executable, self.verify_script, "--file", self.colors_toml, "--json"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(data["status"], "PASS")
        self.assertEqual(len(data["guardrails"]), 8)
        self.assertTrue(all(g["passed"] for g in data["guardrails"]))

    def test_incomplete_colors_fails(self):
        """A colors.toml missing required tokens must fail verification with code 1."""
        with tempfile.NamedTemporaryFile("w+", delete=False, suffix=".toml") as tmp:
            tmp.write('background = "#191716"\n')
            tmp_name = tmp.name

        try:
            res = subprocess.run(
                [sys.executable, self.verify_script, "--file", tmp_name],
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 1, "Incomplete colors.toml should have failed verification")
            self.assertIn("[FAIL]", res.stdout)
            self.assertIn("Missing required token", res.stdout)
        finally:
            os.remove(tmp_name)

    def test_pure_black_background_fails(self):
        """Pure black (#000000) background must fail the halation floor guardrail."""
        with open(self.colors_toml, "r", encoding="utf-8") as f:
            content = f.read()

        bad_content = content.replace('background = "#191716"', 'background = "#000000"')
        with tempfile.NamedTemporaryFile("w+", delete=False, suffix=".toml") as tmp:
            tmp.write(bad_content)
            tmp_name = tmp.name

        try:
            res = subprocess.run(
                [sys.executable, self.verify_script, "--file", tmp_name],
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 1)
            self.assertIn("[FAIL]", res.stdout)
            self.assertIn("Halation Floor", res.stdout)
        finally:
            os.remove(tmp_name)


class TestHerdrSync(unittest.TestCase):
    def setUp(self):
        self.sync_script = os.path.join(SCRIPTS_DIR, "sync-herdr.sh")

    def run_sync(self, initial_toml: str) -> str:
        with tempfile.NamedTemporaryFile("w+", delete=False, suffix=".toml") as tmp:
            tmp.write(initial_toml)
            tmp_name = tmp.name

        try:
            env = os.environ.copy()
            env["HERDR_CONFIG"] = tmp_name
            res = subprocess.run(["bash", self.sync_script], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"sync-herdr.sh failed: {res.stderr}")
            with open(tmp_name, "r", encoding="utf-8") as f:
                return f.read()
        finally:
            os.remove(tmp_name)

    def test_fresh_herdr_config(self):
        """Syncing into config without [theme.custom] must add it cleanly."""
        initial = '[theme]\nname = "terminal"\n'
        result = self.run_sync(initial)
        data = tomllib.loads(result)
        self.assertIn("theme", data)
        self.assertIn("custom", data["theme"])
        self.assertEqual(data["theme"]["custom"]["accent"], "#e59458")
        self.assertEqual(data["theme"]["custom"]["panel_bg"], "#191716")
        self.assertEqual(data["ui"]["accent"], "#e59458")

    def test_ui_table_before_theme_custom(self):
        """Syncing when [ui] precedes [theme.custom] must not drop accent from [theme.custom]."""
        initial = '[ui]\naccent = "#6cb0bf"\n\n[theme.custom]\npanel_bg = "#191716"\n'
        result = self.run_sync(initial)
        data = tomllib.loads(result)
        self.assertEqual(data["ui"]["accent"], "#e59458")
        self.assertEqual(data["theme"]["custom"]["accent"], "#e59458")
        self.assertEqual(data["theme"]["custom"]["panel_bg"], "#191716")

    def test_indented_toml_no_duplicate_keys(self):
        """Indented TOML must not result in duplicate keys or invalid syntax."""
        initial = """[theme.custom]
  panel_bg = "#000000"
  sidebar_bg = "#000000"
  active_row_bg = "#000000"
  surface_dim = "#000000"
  selection_bg = "#000000"
  accent = "#000000"
"""
        result = self.run_sync(initial)
        data = tomllib.loads(result)
        self.assertEqual(data["theme"]["custom"]["panel_bg"], "#191716")
        self.assertEqual(data["theme"]["custom"]["accent"], "#e59458")
        # Ensure panel_bg appears exactly once
        self.assertEqual(result.count("panel_bg"), 1)


class TestStandaloneConfigs(unittest.TestCase):
    def test_alacritty_toml(self):
        path = os.path.join(STANDALONE_DIR, "alacritty", "alacritty.toml")
        with open(path, "rb") as f:
            data = tomllib.load(f)
        self.assertIn("colors", data)

    def test_herdr_toml(self):
        path = os.path.join(STANDALONE_DIR, "herdr", "herdr.toml")
        with open(path, "rb") as f:
            data = tomllib.load(f)
        self.assertIn("theme", data)
        self.assertIn("custom", data["theme"])

    def test_json_files(self):
        json_files = [
            os.path.join(STANDALONE_DIR, "vscode", "terra-theme.json"),
            os.path.join(STANDALONE_DIR, "darkreader", "darkreader.json"),
            os.path.join(STANDALONE_DIR, "browser", "palette.json"),
        ]
        for path in json_files:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            self.assertIsInstance(data, dict)

    def test_lua_syntax(self):
        lua_files = [
            os.path.join(STANDALONE_DIR, "neovim", "terra.lua"),
            os.path.join(STANDALONE_DIR, "neovim", "aether.lua"),
            os.path.join(STANDALONE_DIR, "hyprland", "looknfeel.lua"),
        ]
        for path in lua_files:
            res = subprocess.run(["luac", "-p", path], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"Lua syntax error in {path}: {res.stderr}")


class TestShellScripts(unittest.TestCase):
    def test_bash_syntax(self):
        scripts = [
            os.path.join(SCRIPTS_DIR, "install.sh"),
            os.path.join(SCRIPTS_DIR, "uninstall.sh"),
            os.path.join(SCRIPTS_DIR, "sync-herdr.sh"),
        ]
        for s in scripts:
            res = subprocess.run(["bash", "-n", s], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"Bash syntax error in {s}: {res.stderr}")

    def test_install_dry_run(self):
        install_script = os.path.join(SCRIPTS_DIR, "install.sh")
        res = subprocess.run(["bash", install_script, "--dry-run"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"install.sh --dry-run failed: {res.stderr}")
        self.assertIn("[DRY-RUN]", res.stdout)

    def test_uninstall_dry_run(self):
        uninstall_script = os.path.join(SCRIPTS_DIR, "uninstall.sh")
        res = subprocess.run(["bash", uninstall_script, "--dry-run"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"uninstall.sh --dry-run failed: {res.stderr}")
        self.assertIn("[DRY-RUN]", res.stdout)


if __name__ == "__main__":
    unittest.main()
