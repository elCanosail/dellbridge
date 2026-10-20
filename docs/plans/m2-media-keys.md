# M2 — Media keys and OSD

**Goal:** make the Apple brightness keys control the Dell panel and show a
native HUD, without breaking the rest of the media keys.

**Status:** M2a implemented (brightness keys + OSD); hardware validation pending.
M2b (volume/mute) is the next slice.

## Implemented

- `MediaKeyMonitor`: `CGEventTap` on session `systemDefined` events. Parses the
  `NX_KEYTYPE_BRIGHTNESS_UP` / `DOWN` codes, throttles key repeat, re-enables
  the tap after timeout, and passes every other media key through untouched.
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

- [ ] `make app` builds on macOS.
- [ ] Pressing the Apple brightness keys changes the S2725QC brightness.
- [ ] The OSD appears and shows the new percentage.
- [ ] Play/pause, next/previous and volume keys still work when the Dell is not
      the default output.
- [ ] Without Accessibility permission, the app starts and the keys pass
      through; the menu offers the permission shortcut.

## Evidence

| Date | Mac | macOS | Result | Report |
| --- | --- | --- | --- | --- |
| — | — | — | pending | — |
