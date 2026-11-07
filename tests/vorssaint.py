"""Check shared shortcut ownership and automation rules before applying settings."""

import plistlib
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]

# Shortcut roles and their enable gates follow Vorssaint's GlobalShortcutRole.
# Checking the active set catches collisions when any individual setting changes.
ROLES = {
    "keepAwake": ("keepAwake", ("hotkeyEnabled",)),
    "shelf": ("shelf", ("shelfEnabled", "shelfShortcutEnabled")),
    "switcher": ("switcher", ("switcherEnabled",)),
    "switcherWindow": ("switcher", ("switcherEnabled",)),
    "switcherAllWindows": (
        "switcher",
        ("switcherEnabled", "switcherAllWindowsShortcutEnabled"),
    ),
    "clipboardHistory": (
        "clipboardHistory",
        ("clipboardHistoryEnabled", "clipboardHistoryShortcutEnabled"),
    ),
    "soundOutputSwitcher": ("soundOutputSwitcher", ("soundOutputSwitcherEnabled",)),
    "pastePlain": ("pastePlain", ("pastePlainEnabled",)),
    "finderRename": ("finderRename", ("finderRenameEnabled",)),
    "colorPicker": ("colorPicker", ("colorPickerShortcutEnabled",)),
    "screenOCR": ("screenOCR", ("screenOCRShortcutEnabled",)),
    "micMute": ("micMute", ("micMuteShortcutEnabled",)),
    "quitApps": ("quitApps", ("quitAppsShortcutEnabled",)),
    "quitAppsExceptFront": ("quitApps", ("quitAppsExceptFrontShortcutEnabled",)),
    "quickLauncher": ("quickLauncher", ("quickLauncherShortcutEnabled",)),
    "screenshot": ("screenshot", ("screenshotShortcutEnabled",)),
    "screenshotFullScreen": ("screenshot", ("screenshotFullScreenShortcutEnabled",)),
    "screenshotLastCapture": ("screenshot", ("screenshotLastCaptureShortcutEnabled",)),
    "screenshotClipboard": ("screenshot", ("screenshotClipboardShortcutEnabled",)),
    "screenshotUpload": (
        "screenshot",
        ("screenshotUploadShortcutEnabled", "screenshotSharingEnabled"),
    ),
    "recentCaptures": ("screenshot", ("recentCapturesShortcutEnabled",)),
    "cameraPreview": ("cameraPreview", ("cameraPreviewShortcutEnabled",)),
    "radialMenu": ("radialMenu", ("radialMenuEnabled",)),
    "scratchpad": ("scratchpad", ("scratchpadShortcutEnabled",)),
    "snippetLibrary": ("textSnippets", ("snippetLibraryEnabled",)),
    "commandBar": ("commandBar", ("commandBarShortcutEnabled",)),
    "recorder": ("screenRecorder", ("recorderShortcutEnabled",)),
    "displayBrightnessDecrease": (
        "brightness",
        ("brightnessControlEnabled", "displayBrightnessShortcutsEnabled"),
    ),
    "displayBrightnessIncrease": (
        "brightness",
        ("brightnessControlEnabled", "displayBrightnessShortcutsEnabled"),
    ),
    "keyboardBrightnessDecrease": (
        "brightness",
        ("keyboardBrightnessShortcutsEnabled",),
    ),
    "keyboardBrightnessIncrease": (
        "brightness",
        ("keyboardBrightnessShortcutsEnabled",),
    ),
    "pointerDisplay": ("windowLayout", ("pointerDisplayEnabled",)),
    "notch": ("notch", ("notchEnabled", "notchShortcutEnabled")),
}


def active_shortcuts(settings: dict[str, Any]) -> dict[str, tuple[frozenset[str], int]]:
    result = {}
    for role, (feature, gates) in ROLES.items():
        if not settings.get("featureAvailable." + feature, False):
            continue
        if not all(settings.get(gate, False) for gate in gates):
            continue
        modifiers, code = settings[role + "Shortcut"].split(":")
        result[role] = (frozenset(modifiers.split("+")), int(code))
    return result


class VorssaintConfigurationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        with (ROOT / "dot_config/vorssaint/private_settings.plist").open("rb") as file:
            cls.settings = plistlib.load(file)["settings"]

    settings: dict[str, Any]

    def test_active_shortcuts_are_unique(self) -> None:
        seen: dict[tuple[frozenset[str], int], str] = {}
        for role, shortcut in active_shortcuts(self.settings).items():
            self.assertNotIn(
                shortcut, seen, f"{role} conflicts with {seen.get(shortcut)}"
            )
            seen[shortcut] = role

    def test_utility_shortcuts_leave_editor_and_window_prefixes_available(self) -> None:
        shortcuts = active_shortcuts(self.settings)
        self.assertEqual(shortcuts.pop("commandBar"), (frozenset({"command"}), 49))
        for role, (modifiers, _) in shortcuts.items():
            self.assertTrue({"control", "option", "command"} <= modifiers, role)

    def test_window_and_input_services_have_one_owner(self) -> None:
        for key in (
            "switcherEnabled",
            "windowMaximizeEnabled",
            "windowLayoutShortcutsEnabled",
            "windowDirectionalEnabled",
            "windowEdgeSnapEnabled",
            "windowGestureEnabled",
            "pointerDisplayEnabled",
            "focusFollowsMouseEnabled",
            "superKeyEnabled",
            "switcherTakeOverSystemShortcuts",
            "finderRenameEnabled",
        ):
            self.assertFalse(self.settings[key], key)

    def test_autoquit_protects_development_sessions(self) -> None:
        exceptions = set(self.settings["autoQuitExceptions"])
        self.assertTrue(
            {
                "net.kovidgoyal.kitty",
                "com.apple.Terminal",
                "com.microsoft.VSCode",
                "com.openai.codex",
                "com.google.Chrome",
            }
            <= exceptions
        )

    def test_clipboard_excludes_password_managers(self) -> None:
        self.assertTrue(self.settings["clipboardHistoryFilterSensitiveText"])
        self.assertTrue(
            {"com.1password.1password", "com.bitwarden.desktop"}
            <= set(self.settings["clipboardHistoryIgnoredApps"])
        )
        self.assertGreater(self.settings["clipboardHistoryRetentionDays"], 0)


if __name__ == "__main__":
    unittest.main()
