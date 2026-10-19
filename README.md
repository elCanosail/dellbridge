![dellbridge](docs/assets/banner.svg)

# dellbridge

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black.svg)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-green.svg)
![Status: alpha](https://img.shields.io/badge/status-alpha-orange.svg)

**DellBridge puts the Apple keyboard back in charge of your Dell USB-C monitor.**

macOS ignores the brightness keys on third-party displays. DellBridge talks
DDC/CI to the monitor over the same USB-C cable that carries video and power:
brightness, contrast, volume, input switching, and eventually the media keys
themselves.

Open source, MIT, no account, no telemetry, no background daemon beyond the
menu bar app.

## Features

- **Menu bar control** — brightness and input switching without touching the
  monitor joystick.
- **`dellctl` CLI** — scriptable DDC/CI: `list`, `get`, `set`, `input`.
- **Per-model profiles** — VCP codes and quirks live in JSON, with an explicit
  `verified` flag.
- **Built on proven ground** — the Apple Silicon `IOAVService` path is adapted
  from [m1ddc](https://github.com/waydabber/m1ddc) (MIT).

## Install

The first public release is pending. Once it is published:

```bash
curl -fsSL https://raw.githubusercontent.com/elCanosail/dellbridge/main/install.sh | bash
```

The script downloads the DMG, verifies its SHA-256, copies `DellBridge.app` to
`/Applications`, removes the quarantine flag (the app is ad-hoc signed and not
notarized), and launches it. Read [install.sh](install.sh) before piping it to
a shell; that is always good advice.

Prefer the manual route? Download the DMG from
[Releases](https://github.com/elCanosail/dellbridge/releases), drag the app to
Applications, and right-click → Open the first time.

Homebrew (once the tap is published):

```bash
brew install --cask elcanosail/tap/dellbridge
```

### Requirements

- Apple Silicon Mac (M1 or newer).
- macOS 13 or newer.
- A monitor connected **directly** over USB-C with DisplayPort Alt Mode.
  Docks and hubs frequently drop DDC/CI and are not supported yet.
- DDC/CI enabled in the monitor OSD: **Others → DDC/CI → On**.

## Usage

Menu bar: brightness ±10, input USB-C/HDMI 1/HDMI 2, refresh, quit.

CLI:

```bash
dellctl list
dellctl get brightness
dellctl set brightness 50
dellctl input usb-c
```

`dellctl packet get 10` prints the raw MCCS request, which is useful when
debugging a monitor that does not answer.

## Status

Early alpha, built against a **Dell S2725QC**. The protocol layer and CLI are
tested; the macOS transport is drafted from the m1ddc reference and has not yet
been validated on hardware. The `verified` flag in a profile stays `false`
until a device report proves it.

- M0 — hardware feasibility: pending monitor
- M1 — transport and CLI: implemented, hardware validation pending
- M2 — media keys and OSD: next
- M4 — packaging: DMG and installer ready

See [docs/plans/roadmap.md](docs/plans/roadmap.md).

## How it works

DDC/CI is a small command protocol carried over the I2C line inside the video
cable. On Intel Macs it was reachable through `IOFramebuffer`; on Apple Silicon
it sits behind the private `IOAVService` API. DellBridge encodes MCCS requests,
walks the IORegistry to find the display's AV service, and paces writes so the
shared bus does not jam.

The design and the wire format are documented in
[docs/architecture.md](docs/architecture.md).

## Build from source

Requires macOS 13+ and the Xcode command line tools.

```bash
make test
make app     # dist/DellBridge.app
make dmg     # dist/DellBridge-0.2.0.dmg
```

`make dmg` also writes the SHA-256 file used by the installer. Distribution
details, including the no-notarization trade-off, are in
[docs/plans/m4-distribution.md](docs/plans/m4-distribution.md).

## Contributing

The most useful contribution is a hardware report: run
`./scripts/m0-check.sh --write` and attach the generated report to a **Device
report** issue. Code contributions: see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. DDC/CI packet layout and the Apple Silicon transport approach are adapted
from [m1ddc](https://github.com/waydabber/m1ddc) and
[AppleSiliconDDC](https://github.com/waydabber/AppleSiliconDDC), both MIT.

Not affiliated with Dell. Dell and S2725QC are trademarks of their respective
owners.
