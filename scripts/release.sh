#!/usr/bin/env bash
# One-command release: test, build the DMG, tag, push and publish.
#
# Run on macOS with a clean working tree and an authenticated `gh`.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: releases must be built on macOS." >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: working tree is not clean." >&2
    git status --short
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' packaging/Info.plist)"
TAG="v$VERSION"

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "error: tag $TAG already exists." >&2
    exit 1
fi

make test
make dmg

git tag -a "$TAG" -m "DellBridge $VERSION"
git push origin "$TAG"

gh release create "$TAG" \
    "dist/DellBridge-$VERSION.dmg" \
    "dist/DellBridge-$VERSION.dmg.sha256" \
    --title "DellBridge $VERSION" \
    --generate-notes

echo "✓ published $TAG"
