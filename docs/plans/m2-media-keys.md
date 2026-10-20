# M2 — Media keys and OSD

**Goal:** make the Apple brightness keys control the Dell panel and show a
native HUD, without breaking the rest of the media keys.

**Status:** M2a validated on hardware (2026-10-20); M2b (volume/mute) is the next slice.

## Implemented

- `MediaKeyMonitor`: captures `NX_SYSDEFINED` aux events and the raw F1/F2
  `keyDown` fallback (keycodes 144/145), which is what macOS delivers when the
  built-in display is absent/clamshell. It also installs global/local `NSEvent`
  monitors as a second path, throttles key repeat, re-enables the tap after
  timeout, and passes every other media key through untouched.
- `scripts/build-app.sh`: ad-hoc builds use a stable designated requirement
  (`identifier "es.elcanosail.dellbridge"`) so Accessibility/Input Monitoring
  grants survive rebuilds.
- `OSDController`: non-activating, click-through HUD with a sun symbol and a
  progress bar; auto-hides after 1.2 s and appears on the screen under the
  pointer.
- `AppDelegate`: wires the tap to `DDCClient.change`, prompts for Accessibility,
  exposes `Enable Accessibility…` and `Retry media keys` in the menu, and
  reports whether the tap is active.

## Not implemented yet

- Volume and mute keys routed only when the Dell is the default audio output.
- Target display selection by pointer/fixed display (M2 currently uses the first
  external display).
- Unit tests for the key-code parsing (needs a small pure parser extracted from
  the event tap).

## Acceptance criteria

- [x] `make app` builds on macOS.
- [x] Pressing the Apple brightness keys changes the S2725QC brightness.
- [ ] The OSD appears and shows the new percentage (implemented; explicit visual check pending).
- [ ] Play/pause, next/previous and volume keys still work when the Dell is not
      the default output.
- [ ] Without Accessibility permission, the app starts and the keys pass
      through; the menu offers the permission shortcut.

## Evidence

| Date | Mac | macOS | Result | Report |
| --- | --- | --- | --- | --- |
| 2026-10-20 | MacBook M4 | macOS | Brightness keys change the S2725QC. `/tmp/dellbridge-media.log` shows `keyDown keycode=144/145`; the `NX_SYSDEFINED` path arrives with subtype 7 and is ignored. | commit `0e8615b` |
