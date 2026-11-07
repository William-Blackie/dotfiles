#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    exit 0
fi

# Reserve Command + Space for the managed Vorssaint Command Bar shortcut.
# Update only Spotlight's competing binding, preserving other macOS shortcuts.
spotlight_enabled="$(/usr/libexec/PlistBuddy -c 'Print :AppleSymbolicHotKeys:64:enabled' \
    "$HOME/Library/Preferences/com.apple.symbolichotkeys.plist" 2>/dev/null || true)"
if [[ "$spotlight_enabled" != "false" && "$spotlight_enabled" != "0" ]]; then
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
        '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>'
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
fi
