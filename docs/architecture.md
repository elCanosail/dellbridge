# Architecture

## Layers

```
┌─────────────────────────────────────────────┐
│ DellBridge.app                              │
│  · menu bar (LSUIElement)                   │
│  · CGEventTap for brightness/volume keys    │
│  · native OSD                               │
│  · wake/reconnect observer                  │
├─────────────────────────────────────────────┤
│ dellctl                                     │
│  · scripting and diagnostics                │
├─────────────────────────────────────────────┤
│ DellBridgeCore                              │
│  · MCCS packet encoding (pure Swift)        │
│  · VCP catalogue, input sources             │
│  · display profiles (JSON)                  │
├─────────────────────────────────────────────┤
│ DDCTransport                                │
│  · protocol: read/write VCP                 │
│  · AppleSiliconTransport: IOAVService       │
│  · FakeTransport: tests                     │
└─────────────────────────────────────────────┘
```

## Transport

On Intel Macs DDC/CI was reached through `IOFramebuffer` + `IOI2CInterface`.
That path does not exist on Apple Silicon: display work runs on the DCP
coprocessor and the I2C line sits behind `IOAVService`, an IOKit SPI without a
public header.

The transport will bind the symbols directly:

```
IOAVServiceCreateWithService(allocator, ioService) -> IOAVServiceRef
IOAVServiceWriteI2C(service, chipAddress, dataAddress, buffer, length)
IOAVServiceReadI2C (service, chipAddress, dataAddress, buffer, length)
```

Packet format and checksum are in `Sources/DellBridgeCore/MCCS.swift`. The bus
is shared and slow: all writes go through one serial queue with a minimum gap
(`writeDelayMilliseconds` in the profile, 50 ms for the S2725QC hypothesis).
Slider drags must be coalesced — send only the latest value.

Display enumeration uses CoreGraphics display IDs and the corresponding IOService
to build an `IOAVService`. The exact enumeration path is the first M1 task and
must be validated against hardware; it is the most fragile part of the stack.

## Keyboard routing

macOS consumes the Apple keyboard media keys before applications see them. The
agent installs a `CGEventTap` (requires Accessibility permission) and maps:

- `NX_KEYTYPE_BRIGHTNESS_UP/DOWN` → VCP 0x10 on the target display,
- `NX_KEYTYPE_SOUND_UP/DOWN/MUTE` → VCP 0x62/0x8D when the display is the audio
  output, otherwise the event passes through.

Target selection is configurable: display under the pointer (default) or a fixed
display. The OSD is drawn by the agent, not by the private `OSD.framework`.

Karabiner-Elements is documented as an alternative for users who already run
it, but it is not a dependency.

## Failure modes to handle

- **Sleep/wake:** the DDC link re-handshakes and the monitor may drop the last
  value. Re-apply after wake and after display reconnect.
- **HDR:** VCP 0x10 is ignored while HDR content is active on many Dell panels.
  Detect via `CGDisplay` color space / HDR headroom and fall back to gamma
  dimming only when the user opts in.
- **No response:** retry with a longer delay once, then surface a clear error.
  Never block the UI thread on DDC.
- **Multiple displays:** keep a per-display serial queue; never interleave.

## Distribution

Direct download and Homebrew only. The private `IOAVService` symbols make the
app unsuitable for the Mac App Store. Releases are unsigned at first; Developer
ID signing and notarization are an M4 item, not a prerequisite.
