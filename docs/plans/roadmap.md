# Roadmap

One milestone at a time. A milestone closes only with hardware evidence.

## M0 — Feasibility (done 2026-10-20)

Prove DDC/CI over direct USB-C with `m1ddc`.

- [x] Enable DDC/CI in the monitor OSD
- [x] Read brightness, contrast, volume
- [x] Write and restore brightness
- [x] Record the report in `docs/plans/m0-feasibility.md`

**Exit:** green row in the evidence log. Otherwise the project pivots.

## M1 — Transport and CLI (in progress)

- [x] `DDCTransport` protocol with a fake implementation
- [x] `AppleSiliconTransport` over `IOAVService` (drafted, not hardware-verified)
- [x] Display enumeration and stable identity (vendor/model/serial)
- [x] `dellctl list`, `get`, `set`, `input`, `profile`
- [x] Serialized client with profile-driven write delay and one retry
- [x] Profile loader and S2725QC profile (M0 evidence recorded; transport pending)
- [ ] Compile the macOS target in CI and validate on the S2725QC

**Exit:** CLI controls brightness, contrast, volume and input on the S2725QC;
`swift test` covers protocol and profile parsing.

## M2 — Menu bar and media keys (in progress)

- [ ] `LSUIElement` agent with status item
- [x] `CGEventTap` for brightness keys (M2a)
- [x] Native OSD for brightness (M2a)
- [ ] `CGEventTap` for volume/mute keys (M2b)
- [ ] Target display: pointer or fixed
- [x] Accessibility permission flow (implemented; hardware pending)

**Exit:** Apple keyboard keys change the Dell panel; volume keys follow the
active audio output.

## M3 — Robustness

- [ ] Re-apply state after wake and reconnect
- [ ] HDR detection and documented fallback
- [ ] Multiple displays with independent queues
- [ ] Per-app presets and Shortcuts/URL scheme
- [ ] Dock support matrix (documented quirks, not guaranteed)

**Exit:** a week of daily use without a stuck or drifting value.

## M4 — Distribution (in progress)

- [x] `DellBridge.app` build script with ad-hoc signing
- [x] DMG with drag-to-Applications layout and SHA-256 output
- [x] Homebrew cask template and release workflow (inactive)
- [x] Device report issue template
- [ ] First public DMG release
- [ ] Homebrew tap repository
- [ ] Developer ID signing and notarization
- [ ] Compatibility matrix with at least three Dell models

**Exit:** a new user can install and control the monitor in under five minutes.
