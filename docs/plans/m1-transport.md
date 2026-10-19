# M1 — Transport and CLI

**Goal:** a working DDC/CI path from Swift to the monitor, plus a CLI that can
diagnose and control it.

**Status:** code complete for the portable layer; macOS transport drafted from
the m1ddc reference and waiting for hardware validation. M0 remains the gate.

## Implemented

- `MCCS` — wire encoding for `Get VCP Feature` / `Set VCP Feature`, reply
  parsing, checksum reporting.
- `DDCTransport` — protocol with `readVCP` / `writeVCP`.
- `DDCClient` — serialized access, pacing, one retry, clamping, percent mapping.
- `AppleSiliconDisplays` — online display enumeration via CoreDisplay +
  IORegistry, marking built-in vs external.
- `AppleSiliconTransport` — `IOAVService` I2C transport, including the
  `DCPAVServiceProxy` walk and the MCDP29xx chip address (0xB7).
- `ProfileStore` — JSON loading, directory loading with per-file errors, model
  matching.
- `dellctl` — `list`, `get`, `set`, `input`, `profile`, `packet`, `version`.

## Wire format (verified against the m1ddc reference)

Requests are written to the monitor at I2C offset `0x51`.

```
Get VCP Feature request   (4 bytes): 82 01 <vcp> <checksum>
Set VCP Feature request   (6 bytes): 84 03 <vcp> <hi> <lo> <checksum>
```

- Read checksum: `0x6E ^ 0x82 ^ 0x01 ^ vcp`.
- Write checksum includes the I2C address: `0x6E ^ 0x51 ^ 0x84 ^ 0x03 ^ vcp ^ hi ^ lo`.
- Reply (12 bytes): `6E 88 02 <result> <vcp> <type> <maxHi> <maxLo> <curHi> <curLo> <checksum>`.
- Current value is bytes 8–9, maximum is bytes 6–7, big-endian.

The reply checksum is reported but not enforced: some panels return a sloppy
checksum with a valid payload. `VCPReply.checksumValid` exposes it.

## Pacing

- 10 ms wait before a read; 50 ms for MCDP29xx (empty replies were observed by
  the m1ddc author at 10 ms).
- 20 ms between writes by default, configurable per profile.
- One retry on write failure. No retry loop that can pin the bus.

## Display enumeration

`CGGetOnlineDisplayList` → `CoreDisplay_DisplayCreateInfoDictionary` →
`IODisplayLocation` → `IORegistryEntryCopyFromPath` → match the
`IOMobileFramebuffer` registry id → next `DCPAVServiceProxy` with
`Location == "External"` → `IOAVServiceCreateWithService`.

This is the same walk m1ddc uses. It is the most fragile part of the stack and
the first thing to check if `list` shows a display but `get` fails.

## Open risks

- Private symbols: `IOAVServiceCreateWithService`, `IOAVServiceReadI2C`,
  `IOAVServiceWriteI2C`, `CoreDisplay_DisplayCreateInfoDictionary`. No Mac App
  Store distribution.
- The macOS target has not been compiled here (the development host is Linux).
  CI on `macos-15` is the first check; a device report is the second.
- macOS 26/27 may change the IORegistry layout. m1ddc's Homebrew bottles cover
  Tahoe, which is encouraging but not proof for M5 hardware.

## Acceptance criteria

- [ ] `swift build` passes on macOS.
- [ ] `dellctl list` shows the S2725QC as external.
- [ ] `dellctl get brightness` returns `current/max`.
- [ ] `dellctl set brightness 50` changes the panel.
- [ ] `dellctl set brightness <original>` restores it.
- [ ] `dellctl input usb-c` is idempotent and does not drop the link.

## Evidence log

| Date | Mac | macOS | Result | Report |
| --- | --- | --- | --- | --- |
| — | — | — | pending | — |
