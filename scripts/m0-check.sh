#!/usr/bin/env bash
# M0 feasibility check for dellbridge.
#
# Read-only by default. Pass --write to probe write access by setting and
# restoring brightness, contrast and volume. Never switches input sources.
#
# Usage:
#   ./scripts/m0-check.sh
#   ./scripts/m0-check.sh --write
#
# A report is written to ~/Desktop/dellbridge-m0-report.txt.

set -u

REPORT="${HOME}/Desktop/dellbridge-m0-report.txt"
WRITE=0
[[ "${1:-}" == "--write" ]] && WRITE=1

say() { printf '%s\n' "$*"; }
record() { printf '%s\n' "$*" | tee -a "$REPORT"; }
section() { record ""; record "== $* =="; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  say "This script must run on macOS." >&2
  exit 2
fi

mkdir -p "$(dirname "$REPORT")"
: > "$REPORT"

section "System"
record "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
record "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
record "Hardware: $(sysctl -n hw.model)"
record "Chip: $(sysctl -n machdep.cpu.brand_string)"

section "Displays (system_profiler)"
system_profiler SPDisplaysDataType 2>/dev/null | sed -n '1,80p' | tee -a "$REPORT"

if ! command -v m1ddc >/dev/null 2>&1; then
  record ""
  record "RESULT: BLOCKED — m1ddc not found."
  record "Install it with: brew install m1ddc"
  exit 1
fi

section "m1ddc"
record "Version: $(brew list --versions m1ddc 2>/dev/null || echo 'unknown (not from brew)')"
m1ddc display list detailed 2>&1 | tee -a "$REPORT" || true

section "Read probes"
fail=0
for vcp in luminance contrast volume; do
  if out="$(m1ddc get "$vcp" 2>&1)"; then
    record "$vcp: $out"
  else
    record "$vcp: FAILED — $out"
    fail=1
  fi
done

if [[ $WRITE -eq 1 ]]; then
  section "Write probe (set and restore)"
  for pair in "luminance:50" "contrast:50" "volume:40"; do
    vcp="${pair%%:*}"
    probe="${pair##*:}"
    if ! original="$(m1ddc get "$vcp" 2>/dev/null)"; then
      record "$vcp: no readable value, skipping write probe"
      continue
    fi
    record "$vcp original: $original"
    if m1ddc set "$vcp" "$probe" >/dev/null 2>&1; then
      sleep 0.3
      now="$(m1ddc get "$vcp" 2>/dev/null || echo '?')"
      record "$vcp after set $probe: $now"
      if m1ddc set "$vcp" "$original" >/dev/null 2>&1; then
        record "$vcp restored to $original"
      else
        record "$vcp WARNING: could not restore original value ($original)"
      fi
    else
      record "$vcp: SET FAILED"
      fail=1
    fi
  done
fi

section "Result"
if [[ $fail -eq 0 ]]; then
  record "PASS — DDC/CI responds over this connection."
  record "Attach the report to docs/compatibility.md evidence and open M1."
  exit 0
else
  record "FAIL — at least one probe failed. Check OSD > Others > DDC/CI, cable, and port."
  record "Attach the report to the device-report issue."
  exit 1
fi
