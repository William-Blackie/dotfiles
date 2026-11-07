#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    exit 0
fi

# Reserve Control + Space for tmux and Command + Space for Vorssaint.
# Preserve every other macOS shortcut, including native screenshot shortcuts.
changed=false
for shortcut in 60 64; do
    enabled="$(/usr/libexec/PlistBuddy -c "Print :AppleSymbolicHotKeys:$shortcut:enabled" \
        "$HOME/Library/Preferences/com.apple.symbolichotkeys.plist" 2>/dev/null || true)"
    if [[ "$enabled" == "false" || "$enabled" == "0" ]]; then
        continue
    fi
    if [[ "$shortcut" == "60" ]]; then
        modifiers=262144
    else
        modifiers=1048576
    fi
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$shortcut" \
        "<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>$modifiers</integer></array><key>type</key><string>standard</string></dict></dict>"
    changed=true
done
if [[ "$changed" == "true" ]]; then
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
fi
