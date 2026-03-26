#!/usr/bin/env python3
import os
import subprocess
import unittest


class TestDotfilesEndToEnd(unittest.TestCase):
    """Smoke tests for the repo workflow."""

    @classmethod
    def setUpClass(cls):
        cls.home = os.path.expanduser("~")
        cls.dotfiles = os.path.join(cls.home, ".dotfiles")
        cls.env = os.environ.copy()
        cls.env["TERM"] = "xterm"

    def test_core_symlinks_point_into_dotfiles(self):
        expected_anchors = {
            ".zshrc": "zsh/.zshrc",
            ".zshenv": "shell/.zshenv",
            ".gitconfig": "git/.gitconfig",
            ".config/nvim/init.lua": "nvim/.config/nvim/init.lua",
            ".config/starship.toml": "starship/.config/starship.toml",
        }
        for link_name, target_rel in expected_anchors.items():
            with self.subTest(link=link_name):
                link_path = os.path.join(self.home, link_name)
                self.assertTrue(os.path.islink(link_path))
                self.assertEqual(os.path.realpath(link_path), os.path.realpath(os.path.join(self.dotfiles, target_rel)))

    def test_zsh_configuration_sources_successfully(self):
        result = subprocess.run(
            ["zsh", "-c", "source ~/.zshrc >/dev/null 2>&1; echo READY"],
            capture_output=True,
            text=True,
            env=self.env,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("READY", result.stdout)

    def test_make_edit_points_at_repo(self):
        result = subprocess.run(
            ["make", "-n", "edit"],
            cwd=self.dotfiles,
            capture_output=True,
            text=True,
            env=self.env,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn(f'cd "{self.dotfiles}" && nvim .', result.stdout)

    def test_normalize_stow_links_is_idempotent(self):
        result = subprocess.run(
            [
                "python3",
                "scripts/normalize-stow-links.py",
                self.dotfiles,
                "zsh tmux kitty starship nvim git fzf shell bat",
            ],
            cwd=self.dotfiles,
            capture_output=True,
            text=True,
            env=self.env,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)

if __name__ == "__main__":
    unittest.main(verbosity=2)
