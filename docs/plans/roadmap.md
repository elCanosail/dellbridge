# Roadmap

One milestone at a time. A milestone closes only with hardware evidence.

## M0 — Feasibility (current)

Prove DDC/CI over direct USB-C with `m1ddc`.

- [ ] Enable DDC/CI in the monitor OSD
- [ ] Read brightness, contrast, volume
- [ ] Write and restore brightness
- [ ] Record the report in `docs/plans/m0-feasibility.md`

**Exit:** green row in the evidence log. Otherwise the project pivots.

## M1 — Transport and CLI

- [ ] `DDCTransport` protocol with a fake implementation
- [ ] `AppleSiliconTransport` over `IOAVService`
- [ ] Display enumeration and stable identity (vendor/model/serial)
- [ ] `dellctl list`, `get`, `set`, `input`
- [ ] Serial queue with profile-driven write delay
- [ ] Profile loader and `profiles/s2725qc.json` verified on hardware

**Exit:** CLI controls brightness, contrast, volume and input on the S2725QC;
`swift test` covers protocol and profile parsing.

## M2 — Menu bar and media keys

- [ ] `LSUIElement` agent with status item
- [ ] `CGEventTap` for brightness/volume/mute keys
- [ ] Native OSD
- [ ] Target display: pointer or fixed
- [ ] Accessibility permission flow

**Exit:** Apple keyboard keys change the Dell panel; volume keys follow the
active audio output.

## M3 — Robustness

- [ ] Re-apply state after wake and reconnect
- [ ] HDR detection and documented fallback
- [ ] Multiple displays with independent queues
- [ ] Per-app presets and Shortcuts/URL scheme
- [ ] Dock support matrix (documented quirks, not guaranteed)

**Exit:** a week of daily use without a stuck or drifting value.

## M4 — Distribution

- [ ] Homebrew tap
- [ ] DMG and release notes
- [ ] Developer ID signing and notarization (if justified)
- [ ] Compatibility matrix with at least three Dell models
- [ ] Device report issue template and triage flow

**Exit:** a new user can install and control the monitor in under five minutes.
