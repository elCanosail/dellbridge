# Contributing

## Device reports

The most useful contribution is a hardware report. Run:

```bash
./scripts/m0-check.sh --write
```

and attach `~/Desktop/dellbridge-m0-report.txt` to a **Device report** issue.
Include the monitor model, Mac model, macOS version and cable/port topology.

## Code

- Swift 5.9+, macOS 13+.
- `swift build` and `swift test` must pass.
- Keep the protocol layer pure and testable; hardware access belongs behind a
  transport protocol.
- No new dependency without a reason and a license check.
- Profiles: only claim what a hardware report proves.

## Licensing

By contributing you agree to license your work under the repository's MIT
license. Adapted code must keep its original attribution.
