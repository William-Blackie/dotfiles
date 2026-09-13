#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    exit 0
fi

case "$(uname -m)" in
    arm64)
        ARCH="arm64"
        ;;
    x86_64)
        ARCH="x64"
        ;;
    *)
        echo "Skipping Recordly install: unsupported architecture: $(uname -m)"
        exit 0
        ;;
esac

if [[ -w "/Applications" ]]; then
    APP_DIR="/Applications/Recordly.app"
else
    APP_DIR="${HOME}/Applications/Recordly.app"
fi

# Fetches the latest release tag for Recordly from GitHub.
#
# Outputs:
#   Writes the tag string (e.g. 1.4.0) to stdout.
# Returns:
#   0 if the tag was resolved; non-zero otherwise.
resolve_latest_tag() {
    local location_header
    location_header="$(curl -fsSIL --connect-timeout 5 --max-time 10 "https://github.com/webadderallorg/Recordly/releases/latest" 2>/dev/null | grep -i "^location:" || true)"
    if [[ -z "$location_header" ]]; then
        return 1
    fi
    printf '%s' "$location_header" | sed -E 's/.*\/tag\/v?//' | tr -d '\r\n'
}

LATEST_TAG="$(resolve_latest_tag || true)"

if [[ -z "$LATEST_TAG" ]]; then
    if [[ -d "$APP_DIR" ]]; then
        echo "Notice: Unable to check for latest Recordly release (offline?). Keeping existing install."
        exit 0
    fi
    echo "Warning: Unable to resolve latest Recordly release from GitHub." >&2
    exit 0
fi

if [[ -d "$APP_DIR" ]]; then
    CURRENT_VERSION="$(defaults read "${APP_DIR}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || true)"
    if [[ "$CURRENT_VERSION" == "$LATEST_TAG" ]]; then
        exit 0
    fi
fi

for cmd in curl hdiutil defaults; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Skipping Recordly install: missing required command: $cmd"
        exit 0
    }
done

echo "Installing Recordly v${LATEST_TAG}..."

TEMP_DIR="$(mktemp -d)"
MOUNT_POINT=""

# Cleans up temporary files and unmounts the DMG if attached.
#
# Globals:
#   MOUNT_POINT
#   TEMP_DIR
cleanup() {
    if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    fi
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

DMG_URL="https://github.com/webadderallorg/Recordly/releases/download/v${LATEST_TAG}/Recordly-${ARCH}.dmg"
DMG_PATH="${TEMP_DIR}/Recordly-${ARCH}.dmg"

if ! curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 10 --max-time 300 \
    --output "$DMG_PATH" "$DMG_URL"; then
    echo "Failed to download Recordly from ${DMG_URL}" >&2
    exit 0
fi

MOUNT_OUTPUT="$(hdiutil attach "$DMG_PATH" -nobrowse -readonly 2>/dev/null || true)"
MOUNT_POINT="$(printf '%s\n' "$MOUNT_OUTPUT" | tail -n 1 | awk '{$1=$2=""; print $0}' | sed 's/^ *//')"

if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
    echo "Failed to mount Recordly DMG" >&2
    exit 0
fi

APP_BUNDLE="$(find "$MOUNT_POINT" -maxdepth 2 -name "Recordly.app" -print -quit 2>/dev/null)"
if [[ -z "$APP_BUNDLE" || ! -d "$APP_BUNDLE" ]]; then
    echo "Recordly.app not found in DMG" >&2
    exit 0
fi

mkdir -p "$(dirname "$APP_DIR")"
rm -rf "$APP_DIR"
cp -R "$APP_BUNDLE" "$APP_DIR"

# Clear macOS quarantine attribute so the app opens without warnings
xattr -rd com.apple.quarantine "$APP_DIR" 2>/dev/null || true

hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
MOUNT_POINT=""

echo "Recordly v${LATEST_TAG} installed successfully to ${APP_DIR}."
