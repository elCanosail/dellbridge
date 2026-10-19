#!/usr/bin/env bash
# DellBridge installer.
#
# Downloads the latest release DMG, verifies its SHA-256, installs
# DellBridge.app into /Applications, removes the quarantine flag (the app is
# ad-hoc signed, not notarized) and launches it.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/elCanosail/dellbridge/main/install.sh | bash
#   bash install.sh --no-launch
#   bash install.sh --version 0.2.0 --dest ~/Applications

set -euo pipefail

REPO="${DELLBRIDGE_REPO:-elCanosail/dellbridge}"
APP_NAME="DellBridge.app"
VERSION="${DELLBRIDGE_VERSION:-latest}"
DEST_DIR="${DELLBRIDGE_DEST:-/Applications}"
LAUNCH=1

usage() {
    cat <<'EOF'
DellBridge installer

  --version <x.y.z>   install a specific release (default: latest)
  --dest <dir>        install destination (default: /Applications)
  --no-launch         do not open the app after installing
  -h, --help          show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            [[ $# -ge 2 ]] || { echo "error: --version needs a value" >&2; exit 2; }
            VERSION="$2"
            shift 2
            ;;
        --dest)
            [[ $# -ge 2 ]] || { echo "error: --dest needs a value" >&2; exit 2; }
            DEST_DIR="$2"
            shift 2
            ;;
        --no-launch)
            LAUNCH=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: DellBridge runs on macOS only." >&2
    exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "error: DellBridge requires an Apple Silicon Mac (arm64)." >&2
    exit 1
fi

TMP="$(mktemp -d)"
MOUNT="$TMP/mount"
MOUNTED=0

cleanup() {
    if [[ "$MOUNTED" == "1" ]]; then
        hdiutil detach -quiet "$MOUNT" >/dev/null 2>&1 || true
    fi
    rm -rf "$TMP"
}
trap cleanup EXIT

if [[ "$VERSION" == "latest" ]]; then
    echo "→ looking up the latest release"
    RELEASE_JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")" || {
        echo "error: no release found yet." >&2
        echo "Build one locally with 'make dmg', or wait for the first release." >&2
        exit 1
    }
    DMG_URL="$(printf '%s' "$RELEASE_JSON" \
        | grep -o '"browser_download_url": *"[^"]*\.dmg"' \
        | head -n 1 \
        | sed 's/.*"\(https[^"]*\)"/\1/')"
    if [[ -z "$DMG_URL" ]]; then
        echo "error: the latest release has no DMG asset." >&2
        exit 1
    fi
else
    DMG_URL="https://github.com/$REPO/releases/download/v$VERSION/DellBridge-$VERSION.dmg"
fi

DMG="$TMP/DellBridge.dmg"
echo "→ downloading $DMG_URL"
curl -fL --progress-bar "$DMG_URL" -o "$DMG"

if curl -fsSL "$DMG_URL.sha256" -o "$TMP/dmg.sha256"; then
    EXPECTED="$(awk '{print $1}' "$TMP/dmg.sha256")"
    ACTUAL="$(shasum -a 256 "$DMG" | awk '{print $1}')"
    if [[ "$EXPECTED" != "$ACTUAL" ]]; then
        echo "error: SHA-256 mismatch." >&2
        echo "expected $EXPECTED" >&2
        echo "got      $ACTUAL" >&2
        exit 1
    fi
    echo "→ checksum verified"
else
    echo "warning: no SHA-256 published for this release; continuing." >&2
fi

mkdir -p "$MOUNT"
hdiutil attach -nobrowse -quiet -mountpoint "$MOUNT" "$DMG"
MOUNTED=1

if [[ ! -d "$MOUNT/$APP_NAME" ]]; then
    echo "error: $APP_NAME not found inside the DMG." >&2
    exit 1
fi

pkill -x DellBridge >/dev/null 2>&1 || true
mkdir -p "$DEST_DIR"
rm -rf "$DEST_DIR/$APP_NAME"

if ! cp -R "$MOUNT/$APP_NAME" "$DEST_DIR/$APP_NAME" 2>/dev/null; then
    echo "error: cannot write to $DEST_DIR." >&2
    echo "Try: sudo bash install.sh --dest /Applications" >&2
    exit 1
fi

xattr -dr com.apple.quarantine "$DEST_DIR/$APP_NAME" 2>/dev/null || true

hdiutil detach -quiet "$MOUNT"
MOUNTED=0

echo "✓ installed $DEST_DIR/$APP_NAME"

if [[ "$LAUNCH" == "1" ]]; then
    open "$DEST_DIR/$APP_NAME"
fi
