# M2 — Media keys and OSD

**Goal:** make the Apple brightness keys control the Dell panel and show a
native HUD, without breaking the rest of the media keys.

**Status:** M2a validated on hardware (2026-10-20); M2b implemented and
user-validated (2026-10-20). Refactor `ce278ab` builds; final smoke test after
the code-review changes is pending.

## Implemented

- `MediaKeyMonitor`: one HID tap (session fallback), `NX_SYSDEFINED` plus raw
  F1/F2 keyDown fallback, key-up consumption only when the matching key-down
  was handled, per-direction volume debounce, tap-timeout re-enable, and a
  `stop()` path when no external display is attached.
- Volume/mute: DDC volume on `VCP 0x62`; mute is implemented as volume 0 with
  restore because the S2725QC accepts `VCP 0x8D` writes but does not change its
  reported mute state. DDC work runs on a serial queue; OSD updates hop to main.
- `AppDelegate`: screen/audio-output/wake/Accessibility observers; delayed
  re-connect after USB-C hotplug; forced media-key retry; brightness and
  volume/mute route through the same DDC queue.
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

- Target display selection by pointer/fixed display (M2 currently uses the first
  external display).
- Unit tests for the key-code parsing (needs a small pure parser extracted from
  the event tap).
- Hardware matrix for mute behavior across Dell models (S2725QC mute VCP is
  read-only in practice).

## Acceptance criteria

- [x] `make app` builds on macOS.
- [x] Pressing the Apple brightness keys changes the S2725QC brightness.
- [x] The OSD appears and shows the new percentage.
- [x] Volume up/down/mute work while the Dell is the default output.
- [x] Brightness and volume keys work natively on the MacBook Air when the Dell
      is disconnected.
- [x] Play/pause, next/previous and volume keys still work when the Dell is not
      the default output.
- [ ] Without Accessibility permission, the app starts and the keys pass
      through; the menu offers the permission shortcut.

## Evidence

| Date | Mac | macOS | Result | Report |
| --- | --- | --- | --- | --- |
| 2026-10-20 | MacBook M4 | macOS | Brightness keys change the S2725QC. `/tmp/dellbridge-media.log` shows `keyDown keycode=144/145`; the `NX_SYSDEFINED` path arrives with subtype 7 and is ignored. | commit `0e8615b` |
| 2026-10-20 | MacBook M4 | macOS | Volume down/up/mute and native MacBook fallback validated by user; `VCP 0x62` works, `VCP 0x8D` mute write is a no-op. | commits `d6a2088`…`b6457aa` |
