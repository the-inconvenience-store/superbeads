#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/skills/writing-plans/scripts/validate.sh"
FIXTURES="$ROOT/tests/fixtures/graph-plans"
SKILL="$ROOT/skills/writing-plans/SKILL.md"
TEMPLATE="$ROOT/skills/writing-plans/slice-contract-template.md"
RUNNER="$ROOT/scripts/skill-microtest.py"
SCENARIO="$ROOT/tests/skill-microtests/scenarios/writing-plans-vertical.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

"$VALIDATOR" "$FIXTURES/valid-vertical.json" | tee "$TMP/valid.out"
grep -Fq "2 tasks" "$TMP/valid.out"
grep -Fq "1 outcomes" "$TMP/valid.out"

expect_failure() {
  local fixture="$1" section="$2" reason="$3"
  if "$VALIDATOR" "$FIXTURES/$fixture.json" >"$TMP/$fixture.out" 2>&1; then
    echo "FAIL: $fixture unexpectedly passed" >&2
    exit 1
  fi
  grep -Fq "$section" "$TMP/$fixture.out" || { cat "$TMP/$fixture.out" >&2; exit 1; }
  grep -Eiq "$reason" "$TMP/$fixture.out" || { cat "$TMP/$fixture.out" >&2; exit 1; }
}

expect_failure invalid-horizontal "t1: Integration Checkpoint:" "deferred|horizontal|consumer"
"$VALIDATOR" "$FIXTURES/invalid-resource-conflict.json" | tee "$TMP/resource-conflict.out"
grep -Fq "semantic width 2" "$TMP/resource-conflict.out"
grep -Fq "resource-constrained width 1" "$TMP/resource-conflict.out"
python3 - "$FIXTURES/invalid-resource-conflict.json" "$TMP/resource-token-conflict.json" <<'PY'
import json
import sys
from pathlib import Path

document = json.loads(Path(sys.argv[1]).read_text())
document["nodes"][1]["description"] = document["nodes"][1]["description"].replace(
    "Exclusive resources: report contract", "Exclusive resources: alpha, shared-contract"
)
document["nodes"][2]["description"] = document["nodes"][2]["description"].replace(
    "src/shared.py", "src/other.py"
).replace(
    "Exclusive resources: report contract", "Exclusive resources: shared-contract, beta"
)
Path(sys.argv[2]).write_text(json.dumps(document))
PY
"$VALIDATOR" "$TMP/resource-token-conflict.json" | tee "$TMP/resource-token-conflict.out"
grep -Fq "resource-constrained width 1" "$TMP/resource-token-conflict.out"
expect_failure invalid-orphan-outcome "epic1: Outcome Trace:" "orphan|owner"

python3 - "$FIXTURES/valid-vertical.json" "$TMP" <<'PY'
import copy
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text())
target = Path(sys.argv[2])
source["nodes"][1]["description"] = source["nodes"][1]["description"].replace(
    "- Why this slice exists: prove authority and persistence together.",
    "- Why this slice exists: prove authority and persistence together.\n- Complexity boundaries: authority, persistence.",
)
source["nodes"][2]["description"] = source["nodes"][2]["description"].replace(
    "- Why this slice exists: prevent lower-level evidence substitution.",
    "- Why this slice exists: prevent lower-level evidence substitution.\n- Complexity boundaries: evidence.",
)

unjustified = copy.deepcopy(source)
unjustified["nodes"][2]["description"] = unjustified["nodes"][2]["description"].replace(
    "- Consumes: APPROVAL-API.", "- Consumes: None."
)
(target / "unjustified-edge.json").write_text(json.dumps(unjustified))

redundant = copy.deepcopy(source)
redundant["nodes"][2]["description"] = redundant["nodes"][2]["description"].replace(
    "- Produces: None.", "- Produces: APPROVAL-EVIDENCE."
)
third = copy.deepcopy(redundant["nodes"][2])
third["key"] = "t3"
third["title"] = "Task 3: Integrated release gate"
third["description"] = third["description"].replace(
    "- Produces: APPROVAL-EVIDENCE.\n- Consumes: APPROVAL-API.",
    "- Produces: None.\n- Consumes: APPROVAL-EVIDENCE, APPROVAL-API.",
).replace("tests/test_approval_outcome.py", "tests/test_approval_release.py").replace(
    "final approval evidence", "release approval evidence"
)
redundant["nodes"].append(third)
redundant["edges"].extend([
    {"from_key": "t3", "to_key": "t2", "type": "blocks"},
    {"from_key": "t3", "to_key": "t1", "type": "blocks"},
])
(target / "redundant-edge.json").write_text(json.dumps(redundant))

oversized = copy.deepcopy(source)
oversized["nodes"][1]["description"] = oversized["nodes"][1]["description"].replace(
    "Complexity boundaries: authority, persistence.",
    "Complexity boundaries: authority, parsing, persistence.",
)
(target / "oversized-slice.json").write_text(json.dumps(oversized))

dense = copy.deepcopy(source)
dense["nodes"][1]["description"] = dense["nodes"][1]["description"].replace(
    "## Integration Checkpoint",
    "- criterion two\n- criterion three\n- criterion four\n- criterion five\n- criterion six\n- criterion seven\n\n## Integration Checkpoint",
)
(target / "dense-acceptance.json").write_text(json.dumps(dense))
PY

if "$VALIDATOR" "$TMP/unjustified-edge.json" >"$TMP/unjustified.out" 2>&1; then
  echo "FAIL: ordering-only blocks edge unexpectedly passed" >&2
  exit 1
fi
grep -Fq "unjustified blocks edge" "$TMP/unjustified.out" || { cat "$TMP/unjustified.out" >&2; exit 1; }

if "$VALIDATOR" "$TMP/redundant-edge.json" >"$TMP/redundant.out" 2>&1; then
  echo "FAIL: transitively redundant edge unexpectedly passed" >&2
  exit 1
fi
grep -Fq "transitively redundant" "$TMP/redundant.out" || { cat "$TMP/redundant.out" >&2; exit 1; }

if "$VALIDATOR" "$TMP/oversized-slice.json" >"$TMP/oversized.out" 2>&1; then
  echo "FAIL: oversized multi-boundary slice unexpectedly passed" >&2
  exit 1
fi
grep -Fq "slice complexity" "$TMP/oversized.out" || { cat "$TMP/oversized.out" >&2; exit 1; }

if "$VALIDATOR" "$TMP/dense-acceptance.json" >"$TMP/dense.out" 2>&1; then
  echo "FAIL: dense multi-result acceptance surface unexpectedly passed" >&2
  exit 1
fi
grep -Fq "acceptance density" "$TMP/dense.out" || { cat "$TMP/dense.out" >&2; exit 1; }

for section in Context Outcome "Domain Contract" Files Resources Interfaces "Acceptance Criteria" "Integration Checkpoint" "Implementation Notes"; do
  grep -Fq "## $section" "$TEMPLATE" || { echo "FAIL: template missing $section" >&2; exit 1; }
done
grep -Fq "one graph producer" "$SKILL"
grep -Fq "first consumer" "$SKILL"
grep -Fq "resource conflicts are not dependency edges" "$SKILL"
grep -Fq "edge deletion test" "$SKILL"
grep -Fq "Complexity boundaries" "$TEMPLATE"
grep -Fq "Acceptance surface" "$TEMPLATE"
grep -Fq "full-code snippets" "$SKILL"
grep -Fq "creates issues, including duplicate epics" "$SKILL"
grep -Fq "scripts/validate.sh <graph>" "$SKILL"
if grep -Fq 'Run `python3 ./skills/writing-plans/scripts/validate-graph-plan.py <graph>` and `bd create --graph <graph> --dry-run`' "$SKILL"; then
  echo "FAIL: skill still instructs the unsafe graph-import dry run" >&2
  exit 1
fi

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
