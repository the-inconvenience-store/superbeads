#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/skills/writing-plans/scripts/validate-graph-plan.py"
FIXTURES="$ROOT/tests/fixtures/graph-plans"
SKILL="$ROOT/skills/writing-plans/SKILL.md"
TEMPLATE="$ROOT/skills/writing-plans/slice-contract-template.md"
RUNNER="$ROOT/scripts/skill-microtest.py"
SCENARIO="$ROOT/tests/skill-microtests/scenarios/writing-plans-vertical.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 "$VALIDATOR" "$FIXTURES/valid-vertical.json" | tee "$TMP/valid.out"
grep -Fq "2 tasks" "$TMP/valid.out"
grep -Fq "1 outcomes" "$TMP/valid.out"

expect_failure() {
  local fixture="$1" section="$2" reason="$3"
  if python3 "$VALIDATOR" "$FIXTURES/$fixture.json" >"$TMP/$fixture.out" 2>&1; then
    echo "FAIL: $fixture unexpectedly passed" >&2
    exit 1
  fi
  grep -Fq "$section" "$TMP/$fixture.out" || { cat "$TMP/$fixture.out" >&2; exit 1; }
  grep -Eiq "$reason" "$TMP/$fixture.out" || { cat "$TMP/$fixture.out" >&2; exit 1; }
}

expect_failure invalid-horizontal "t1: Integration Checkpoint:" "deferred|horizontal|consumer"
expect_failure invalid-resource-conflict "Resources:" "conflict|shared.py"
expect_failure invalid-orphan-outcome "epic1: Outcome Trace:" "orphan|owner"

for section in Context Outcome "Domain Contract" Files Resources Interfaces "Acceptance Criteria" "Integration Checkpoint" "Implementation Notes"; do
  grep -Fq "## $section" "$TEMPLATE" || { echo "FAIL: template missing $section" >&2; exit 1; }
done
grep -Fq "one graph producer" "$SKILL"
grep -Fq "first consumer" "$SKILL"
grep -Fq "resource conflicts are not dependency edges" "$SKILL"
grep -Fq "full-code snippets" "$SKILL"

EVIDENCE="$TMP/evidence"
python3 "$RUNNER" --scenario "$SCENARIO" --provider fake --runs 2 \
  --max-runs 5 --concurrency 2 --evidence-dir "$EVIDENCE" \
  >"$TMP/scenario.json" 2>"$TMP/scenario.err"
python3 - "$TMP/scenario.json" "$TMP/scenario.err" <<'PY'
import json, shutil, sys
from pathlib import Path
report=json.loads(Path(sys.argv[1]).read_text())
assert report["passed"] is True
assert report["aggregate"]["candidate_mean"] >= 0.9
assert set(report["samples"][0]["candidate"]["result"]["rubric_scores"]) == {
    "vertical_slice", "outcome_ownership", "resource_declarations", "early_integration"
}
raw=Path(sys.argv[2]).read_text().strip().split("=",1)[1]
shutil.rmtree(raw)
PY

echo "PASS: vertical graph plan contract"
