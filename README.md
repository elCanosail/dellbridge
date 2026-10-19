# dellbridge

Open macOS bridge for Dell USB-C monitors: DDC/CI CLI, Apple-keyboard routing
and per-model profiles.

**Status: M1 — transport drafted, awaiting hardware.** The protocol core, the
macOS transport and the CLI are implemented. Hardware validation is blocked on
the monitor; the menu bar agent is M2. Nothing is marked verified until it
passes on real hardware.

## Why

macOS does not route the Apple keyboard's brightness and volume keys to
third-party displays. Dell's own DDPM is closed, menu-bar oriented and does not
solve the keyboard problem. The low-level work — talking DDC/CI over
`IOAVService` on Apple Silicon — is already solved in the open by
[m1ddc](https://github.com/waydabber/m1ddc) and
[AppleSiliconDDC](https://github.com/waydabber/AppleSiliconDDC).

dellbridge is the missing bridge: a small, auditable, MIT-licensed layer with

- a CLI (`dellctl`) for scripting and diagnostics,
- a menu bar agent that owns the media keys and shows a native OSD,
- per-model profiles with explicit quirks and a verification flag.

## Target

- Apple Silicon Mac (M4/M5), latest macOS.
- Direct USB-C cable: DisplayPort 1.4 Alt Mode plus power delivery. No dock.
- First profile: **Dell S2725QC** (27" 4K, 65 W USB-C).

Docks and hubs drop DDC/CI often enough that they are out of scope for the
first milestone; support may be added later as a documented quirk.

## Quick start (hardware check)

```bash
brew install m1ddc
git clone https://github.com/elCanosail/dellbridge.git
cd dellbridge
./scripts/m0-check.sh          # read-only
./scripts/m0-check.sh --write  # set and restore brightness/contrast/volume
```

The script writes `~/Desktop/dellbridge-m0-report.txt`. Attach it to a
**Device report** issue.

Before running, enable DDC/CI on the monitor:
**OSD → Others → DDC/CI → On**.

## Build and test

Requires macOS 13+ and Swift 5.9+ (Xcode command line tools).

```bash
swift build
swift test
./.build/debug/dellctl packet set 10 50
./.build/debug/dellctl profile profiles/s2725qc.json
```

Display control (macOS only):

```bash
./.build/debug/dellctl list
./.build/debug/dellctl get brightness
./.build/debug/dellctl set brightness 50
./.build/debug/dellctl input usb-c
```

`dellctl packet` only encodes the wire payload and prints it as hex; it works
without hardware. `list`, `get`, `set` and `input` require macOS and a display
that answers DDC/CI.

## Repository layout

```
Sources/DellBridgeCore/   protocol, transport, client, profiles
Sources/dellctl/          command line interface
profiles/                 per-model JSON profiles
scripts/m0-check.sh       hardware feasibility check
docs/                     architecture, roadmap, compatibility
```

## Roadmap

See [docs/plans/roadmap.md](docs/plans/roadmap.md). M0 decides everything: if
DDC/CI does not answer over USB-C, the project pivots before writing a
transport.

## License and attribution

MIT. The DDC/CI packet layout and the Apple Silicon `IOAVService` approach are
adapted from
[m1ddc](https://github.com/waydabber/m1ddc) (MIT) by waydabber, and from
[AppleSiliconDDC](https://github.com/waydabber/AppleSiliconDDC) (MIT).

Not affiliated with Dell. Dell and S2725QC are trademarks of their respective
owners.
