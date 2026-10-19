# M4 — Distribution

**Goal:** anyone can install DellBridge in under five minutes.

## Reality check

The hard constraint is macOS Gatekeeper, not packaging. There are three tiers.

### Tier 1 — DMG + ad-hoc signature (works today, no Apple account)

```bash
make test
make dmg
```

This produces `dist/DellBridge-0.2.0.dmg` with a drag-to-Applications layout.
The app is ad-hoc signed (`codesign -s -`), which prevents the "app is damaged"
error on Apple Silicon, but Gatekeeper still shows "unidentified developer" on
first launch. The user must use **System Settings → Privacy & Security → Open
Anyway**, or right-click → Open.

This is free, reproducible, and takes minutes. It is not frictionless for a
non-technical user.

### Tier 2 — Developer ID + notarization (recommended for "anyone")

Requires the Apple Developer Program (99 USD/year).

1. Create a **Developer ID Application** certificate.
2. Build with the identity and hardened runtime:

   ```bash
   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make app
   ```

3. Store notary credentials once:

   ```bash
   xcrun notarytool store-credentials dellbridge \
     --apple-id "you@example.com" \
     --team-id "TEAMID" \
     --password "app-specific-password"
   ```

4. Build and notarize the DMG:

   ```bash
   NOTARIZE=1 make dmg
   ```

   The script submits with `notarytool --wait` and staples the ticket.

A notarized DMG opens with no warning on any Mac. This is the only way to get a
true double-click install for the general public. A `.pkg` is not necessary for
a menu bar app and adds an Installer certificate to manage.

### Tier 3 — Mac App Store

Not possible. The transport uses the private `IOAVService` API and the App
Sandbox has no entitlement for raw I2C/DDC. Do not pursue.

## Homebrew

A tap gives technical users a one-command install:

```bash
brew install --cask elcanosail/tap/dellbridge
```

Setup:

1. Create the repository `elCanosail/homebrew-tap`.
2. Copy `packaging/homebrew/dellbridge.rb` to `Casks/dellbridge.rb`.
3. Replace the SHA-256 with the one printed by `make dmg`.
4. Each release: bump `version`, update `sha256`.

The cask respects Gatekeeper exactly like a manual DMG download; notarization
is still what removes the warning.

## Release checklist

- [ ] Bump `CFBundleShortVersionString` / `CFBundleVersion` in `packaging/Info.plist`
- [ ] `make test`
- [ ] `make dmg`
- [ ] Verify on a clean Mac with no Xcode or Homebrew
- [ ] Tag `vX.Y.Z` and push the tag
- [ ] Upload the DMG and its SHA-256 to the GitHub release
- [ ] Update the cask version and SHA-256
- [ ] `brew audit --cask dellbridge`

## CI

`ci/release.yml` builds the DMG on `macos-15` when a `v*` tag is pushed and
attaches it to the release. It stays inactive until the credential gains the
`workflow` scope (see `ci/README.md`).

## Future

- Sparkle for auto-updates, once there is a stable release channel.
- Universal binary (`x86_64` + `arm64`) is unnecessary: the DDC path is Apple
  Silicon only.
- A signed `.pkg` only if enterprise deployment ever matters.
