#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EPOCH="$ROOT/skills/writing-plans/scripts/execution-epoch.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PYTHONPYCACHEPREFIX="$TMP/pycache"

REPO="$TMP/repo"
mkdir -p "$REPO/docs/product" "$REPO/docs/specs" "$REPO/docs/plans"
printf '%s\n' '# Product contract' >"$REPO/docs/product/feature.md"
printf '%s\n' '# Design' >"$REPO/docs/specs/feature.md"
printf '%s\n' '{"nodes":[],"edges":[]}' >"$REPO/docs/plans/feature.graph.json"
cat >"$REPO/docs/specs/feature-seams.json" <<'JSON'
{
  "schema_version": 1,
  "seams": [
    {
      "id": "SEAM-AUTH",
      "high_risk_boundaries": ["authority", "security"],
      "acceptance_surface": "Authorize one production request",
      "journey": {
        "entry": "public request",
        "proof": "signed credential",
        "authority": "server authority store",
        "process_crossing": "signed worker request",
        "durable_owner": "profile database",
        "recovery": "restart and revalidate",
        "evidence": "built service test"
      }
    }
  ]
}
JSON

python3 "$EPOCH" approve \
  --repo "$REPO" \
  --graph docs/plans/feature.graph.json \
  --artifact docs/product/feature.md \
  --artifact docs/specs/feature.md \
  --seams docs/specs/feature-seams.json \
  --approved-at 2026-07-30T00:00:00Z \
  --output "$REPO/docs/plans/feature.epoch.json"

python3 "$EPOCH" check \
  --repo "$REPO" "$REPO/docs/plans/feature.epoch.json" \
  | grep -Fq "PASS approved execution epoch"

printf '%s\n' '# Design changed' >"$REPO/docs/specs/feature.md"
if python3 "$EPOCH" check \
  --repo "$REPO" "$REPO/docs/plans/feature.epoch.json" \
  >"$TMP/design-dirty.out" 2>&1; then
  echo "FAIL: changed design kept an approved epoch" >&2
  exit 1
fi
grep -Fq "DESIGN_DIRTY" "$TMP/design-dirty.out"
grep -Fq "docs/specs/feature.md" "$TMP/design-dirty.out"

printf '%s\n' '# Design' >"$REPO/docs/specs/feature.md"
printf '%s\n' '{"nodes":[{"key":"changed"}],"edges":[]}' >"$REPO/docs/plans/feature.graph.json"
if python3 "$EPOCH" check \
  --repo "$REPO" "$REPO/docs/plans/feature.epoch.json" \
  >"$TMP/graph-dirty.out" 2>&1; then
  echo "FAIL: changed graph kept an approved epoch" >&2
  exit 1
fi
grep -Fq "DESIGN_DIRTY" "$TMP/graph-dirty.out"
grep -Fq "docs/plans/feature.graph.json" "$TMP/graph-dirty.out"

python3 "$EPOCH" invalidate \
  "$REPO/docs/plans/feature.epoch.json" \
  --reason contract-gap \
  --output "$TMP/dirty-epoch.json"
if python3 "$EPOCH" check --repo "$REPO" "$TMP/dirty-epoch.json" \
  >"$TMP/invalidated.out" 2>&1; then
  echo "FAIL: invalidated epoch passed" >&2
  exit 1
fi
grep -Fq "DESIGN_DIRTY" "$TMP/invalidated.out"
grep -Fq "contract-gap" "$TMP/invalidated.out"

echo "PASS: immutable approved execution epoch"
