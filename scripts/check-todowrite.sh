#!/usr/bin/env bash
# Canonical TodoWrite gate — single source of truth. CI, tests, and docs all
# reference THIS script; do not re-inline the filter anywhere.
# Limitation: the prohibition-vocabulary exclusion is line-based, so a single
# line that BOTH forbids and prescribes TodoWrite is out of threat model. The
# real threat is bare prescriptive lines from upstream adoption (no prohibition
# vocabulary), which this catches.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$ROOT/skills}"
results=$(grep -rn "TodoWrite" "$TARGET" \
  | grep -v "Do NOT use TodoWrite" \
  | grep -v "replaces TodoWrite" \
  | grep -v "TodoWrite is forbidden" \
  | grep -v "auditing-upstream-drift" || true)
if [ -n "$results" ]; then
  echo "::error::Active TodoWrite references found:"
  echo "$results"
  exit 1
fi
echo "No active TodoWrite references"
