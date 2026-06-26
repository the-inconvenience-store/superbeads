#!/usr/bin/env bash
# Contract test for getting-up-to-speed Phase-4 output contract.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/skills/getting-up-to-speed/SKILL.md"
fail=0

check_exact() {  # behavioral output string — fixed-string, must be present
  if grep -Fq "$1" "$SKILL"; then echo "PASS: $1"; else echo "FAIL: missing — $1"; fail=1; fi
}
check_loose() {  # structural header — case-insensitive substring, must be present
  if grep -iq "$1" "$SKILL"; then echo "PASS: $1"; else echo "FAIL: missing — $1"; fail=1; fi
}

# Behavioral contract strings — exact
check_exact "I'm ready for your next instruction"
check_exact "Do NOT auto-claim"
# Structural headers — loose (ASCII substrings, no em-dash/parenthetical)
check_loose "Phase 4"
check_loose "Current State"
check_loose "Recent Activity"
check_loose "Verification Gate"
check_loose "Output Contract"

[ "$fail" -eq 0 ] && echo "PASS: getting-up-to-speed contract" || exit 1
