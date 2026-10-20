# M0 — Feasibility

**Goal:** prove that DDC/CI answers over the exact target topology before
building a transport.

**Topology:** Apple Silicon M4/M5 Mac, latest macOS, one direct USB-C cable
(video + power), Dell S2725QC.

**Status:** PASS — 2026-10-20. M0 closed; M1 transport pending.

## Checklist

1. Monitor OSD → **Others → DDC/CI → On**.
2. Mac connected directly with the USB-C cable that came with the monitor.
   No dock, no hub, no adapter.
3. Install the reference tool: `brew install m1ddc`.
4. Run the read-only check:

   ```bash
   ./scripts/m0-check.sh
   ```

5. If reads pass, run the write probe:

   ```bash
   ./scripts/m0-check.sh --write
   ```

6. Save `~/Desktop/dellbridge-m0-report.txt` and attach it to the milestone
   issue.

## Decision tree

| Outcome | Meaning | Next step |
| --- | --- | --- |
| `luminance`, `contrast` and `volume` read and write | Green light | Close M0, start M1 transport |
| Reads work, writes fail | Timing or firmware quirk | Retry with `m1ddc` after a 1 s gap; check OSD DDC/CI again; try another known-good cable |
| Only brightness works | Normal for many panels | Scope M1 to supported VCPs; mark volume/mute unsupported in the profile |
| Nothing responds, but Dell DDPM controls the monitor | Dell uses a channel m1ddc does not speak | Stop and reassess: either narrow the project to keyboard/OSD automation over DDPM's supported surface, or budget reverse engineering |
| Nothing responds and DDPM also fails | Cable, port, firmware or OSD issue | Update monitor firmware from Dell support, test another cable/Mac before touching code |

## Acceptance criteria

- `m1ddc get luminance` returns a number.
- `m1ddc set luminance 50` changes the panel and `get` reflects it.
- The original value is restored.
- The report records macOS version, chip, and the exact cable/port used.

## Evidence log

Append results here as they arrive. Do not mark the profile `verified` before
this table has a green row.

| Date | Mac | macOS | Cable/port | Result | Report |
| --- | --- | --- | --- | --- | --- |
| 2026-10-20 | Mac16,13 (Apple M4) | 26.6.2 (25G83) | direct USB-C | PASS — luminance 75→50→75, contrast 75→50→75, volume 50→40→50; input not probed | m1ddc 1.2.0, report attached |

## Result detail

- Display: Dell S2725QC, vendor `0x10AC`, model `0xA272`, serial `811159618`,
  EDID UUID `10AC72A2-0000-0000-1C24-0104B53C2278`.
- Mac: Mac16,13, Apple M4, macOS 26.6.2, 6016×3384 @ 120 Hz over direct USB-C.
- `m1ddc 1.2.0` read and restored brightness, contrast and volume.
- Input switching was not probed; the S2725QC input VCP values remain a
  hypothesis until M1 validates them.
