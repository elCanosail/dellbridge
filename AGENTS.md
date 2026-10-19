# AGENTS.md — dellbridge

## What this repository is

An open macOS bridge for Dell USB-C monitors. Target: Apple Silicon M4/M5,
latest macOS, direct USB-C single cable. First device: Dell S2725QC.

## Ground rules

- **Hardware is the source of truth.** Never mark a profile, VCP code or quirk
  verified without a report from a real unit (command, output, macOS version,
  connection topology).
- **Do not invent VCP values or EDID data.** Unknown fields stay `null` and the
  profile stays `verified: false`.
- The transport uses the private `IOAVService` API. That is deliberate and
  accepted. It means no Mac App Store distribution; ship via Homebrew/DMG.
- Docks are out of scope until M3. Test direct USB-C only.
- Preserve attribution to m1ddc and AppleSiliconDDC. MIT license stays.

## Build and test

```bash
swift build
swift test
```

CI runs on `macos-15`. Hardware tests are manual and documented in
`docs/plans/m0-feasibility.md`.

## Workflow

- Branches: `feat/`, `fix/`, `chore/`.
- One plan doc per milestone in `docs/plans/`; update it as items close.
- Conventional commits: `type(scope): description`.
- Review the diff and test output before committing. Do not use `git add -A`
  blindly.
- Keep `README.md`, `docs/compatibility.md` and the profile `verified` flags in
  sync with reality.
