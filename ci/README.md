# CI workflow (inactive)

`ci.yml` is the macOS build-and-test workflow. `release.yml` builds and
publishes the DMG on a `v*` tag. They live here instead of `.github/workflows/`
because the credential used for the initial bootstrap lacked the `workflow`
OAuth scope, and GitHub rejects workflow files pushed by such an app.

To activate it:

1. Move `ci/ci.yml` to `.github/workflows/ci.yml`.
2. Push with a credential that has the `workflow` scope (interactive
   `gh auth refresh -s workflow`, or a PAT), or paste the file through the
   GitHub web UI.

Until then, `swift build && swift test` locally is the verification gate.
