# Compatibility

Only rows backed by a hardware report count. `verified` in a profile means the
M0 evidence is recorded and DellBridge's own transport has validated the VCPs
on a real unit; an M0 PASS alone does not flip it.

| Monitor | Connection | Brightness | Contrast | Volume | Input | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Dell S2725QC | direct USB-C (DP 1.4 Alt Mode, 65 W) | PASS (75↔50) | PASS (75↔50) | PASS (50↔40) | — | M0 PASS 2026-10-20; M1 transport/input pending |

## Known constraints

- DDC/CI must be enabled in **OSD → Others → DDC/CI**.
- Docks and hubs frequently drop DDC/CI. Out of scope until M3.
- While HDR content is active, VCP 0x10 is typically ignored.
- Apple Silicon reaches DDC through the private `IOAVService` API.
- The built-in HDMI port of some Apple Silicon Macs does not carry DDC. The
  target topology is direct USB-C, which does.

## Reporting

Run `./scripts/m0-check.sh --write` and attach the report to a Device report
issue. Include the exact cable and port.
