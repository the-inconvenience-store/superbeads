#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESEARCH="$ROOT/skills/research-driven-development/SKILL.md"
RESEARCHER="$ROOT/skills/research-driven-development/researcher-prompt.md"
QUESTION_PLANNER="$ROOT/skills/research-driven-development/question-planner-prompt.md"
PLAN="$ROOT/skills/writing-plans/SKILL.md"
RENDER="$ROOT/skills/writing-plans/scripts/render-review-digest.py"
GRAPH="$ROOT/tests/fixtures/graph-plans/valid-vertical.json"
FINISH="$ROOT/skills/finishing-a-development-branch/SKILL.md"
EVIDENCE="$ROOT/skills/subagent-driven-development/scripts/sdd-evidence.py"
USING="$ROOT/skills/using-superpowers/SKILL.md"
ROUTER="$ROOT/skills/using-superpowers/scripts/workflow-route.py"
WRITING="$ROOT/skills/writing-skills/SKILL.md"
LEDGER="$ROOT/tests/fixtures/sdd-evidence/pass.json"
RUNNER="$ROOT/scripts/skill-microtest.py"
SCENARIO="$ROOT/tests/skill-microtests/scenarios/research-neutral-observer.json"
METRICS="$ROOT/scripts/workflow-metrics.py"
BASELINE="$ROOT/tests/fixtures/workflow-metrics/baseline.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PYTHONPYCACHEPREFIX="$TMP/pycache"

for text in "solution-neutral" "fresh context" "question-planner-prompt.md"; do
  grep -Fqi "$text" "$RESEARCH" || { echo "FAIL: research workflow missing $text" >&2; exit 1; }
done
for text in "Proposed solution: intentionally withheld" "current-state facts" "Do not recommend"; do
  grep -Fqi "$text" "$RESEARCHER" || { echo "FAIL: repository observer missing $text" >&2; exit 1; }
done
for text in "implementation details" "solution-neutral questions" "Do not ask"; do
  grep -Fqi "$text" "$QUESTION_PLANNER" || { echo "FAIL: question planner missing $text" >&2; exit 1; }
done

python3 -m py_compile "$RENDER" "$ROUTER" "$EVIDENCE"
python3 "$RENDER" "$GRAPH" >"$TMP/digest.md"
for text in "Graph SHA-256" "## Destination" "## Execution Outline" \
  "Task 1: Approve and retrieve one draft" "Task 2: Final approval outcome gate" \
  "## Review Hotspots" "## Open Items"; do
  grep -Fq "$text" "$TMP/digest.md" || { echo "FAIL: review digest missing $text" >&2; exit 1; }
done
python3 - "$GRAPH" "$TMP/digest.md" <<'PY'
import hashlib
import re
import sys
from pathlib import Path

graph = Path(sys.argv[1]).read_bytes()
digest = Path(sys.argv[2]).read_text()
match = re.search(r"Graph SHA-256: `([0-9a-f]{64})`", digest)
assert match and match.group(1) == hashlib.sha256(graph).hexdigest()
PY
grep -Fq "render-review-digest.py" "$PLAN"
grep -Fqi "approval applies to the named graph hash" "$PLAN"

REVIEW_REPO="$TMP/review-repo"
mkdir -p "$REVIEW_REPO"
git -C "$REVIEW_REPO" init -q
git -C "$REVIEW_REPO" config user.email "review-test@example.test"
git -C "$REVIEW_REPO" config user.name "Review Test"
git -C "$REVIEW_REPO" commit --allow-empty -q -m root
ROOT_SHA="$(git -C "$REVIEW_REPO" rev-parse HEAD)"
git -C "$REVIEW_REPO" commit --allow-empty -q -m base
BASE_SHA="$(git -C "$REVIEW_REPO" rev-parse HEAD)"
git -C "$REVIEW_REPO" switch -q -c feature
git -C "$REVIEW_REPO" commit --allow-empty -q -m head
HEAD_SHA="$(git -C "$REVIEW_REPO" rev-parse HEAD)"

python3 - "$TMP" "$ROOT_SHA" "$BASE_SHA" "$HEAD_SHA" <<'PY'
import json
import sys
from pathlib import Path

target = Path(sys.argv[1])
root, base, head = sys.argv[2:]
target.joinpath("human-approved.json").write_text(json.dumps({
    "schema_version": 1,
    "required": True,
    "reason": "production-impacting change",
    "base": base,
    "head": head,
    "reviewer": "code-owner@example.test",
    "verdict": "APPROVED",
    "recorded_at": "2026-07-23T00:00:00Z",
}))
target.joinpath("human-stale.json").write_text(json.dumps({
    "schema_version": 1,
    "required": True,
    "reason": "production-impacting change",
    "base": base,
    "head": root,
    "reviewer": "code-owner@example.test",
    "verdict": "APPROVED",
    "recorded_at": "2026-07-23T00:00:00Z",
}))
target.joinpath("human-wrong-base.json").write_text(json.dumps({
    "schema_version": 1,
    "required": True,
    "reason": "production-impacting change",
    "base": root,
    "head": head,
    "reviewer": "code-owner@example.test",
    "verdict": "APPROVED",
    "recorded_at": "2026-07-23T00:00:00Z",
}))
target.joinpath("human-bypass.json").write_text(json.dumps({
    "schema_version": 1,
    "required": False,
    "reason": "approved mechanical-only bypass",
    "base": base,
    "head": head,
    "reviewer": "maintainer@example.test",
    "verdict": "NOT_REQUIRED",
    "recorded_at": "2026-07-23T00:00:00Z",
}))
target.joinpath("route.json").write_text(json.dumps({
    "schema_version": 1,
    "research": "complete",
    "product_contract": "approved",
    "design": "approved",
    "stress_test": "not_required",
    "plan": "missing",
    "execution": "not_started",
    "acceptance": "not_started",
    "human_review": "missing",
}))
target.joinpath("invalid-route.json").write_text(json.dumps({
    "schema_version": 1,
    "research": "complete",
    "product_contract": "missing",
    "design": "approved",
    "stress_test": "not_required",
    "plan": "missing",
    "execution": "not_started",
    "acceptance": "not_started",
    "human_review": "missing",
}))
PY

python3 - "$LEDGER" "$TMP/current-ledger.json" "$BASE_SHA" "$HEAD_SHA" <<'PY'
import json
import sys
from pathlib import Path

value = json.loads(Path(sys.argv[1]).read_text())
value["current"]["base_commit"] = sys.argv[3]
value["current"]["commit"] = sys.argv[4]
Path(sys.argv[2]).write_text(json.dumps(value))
PY

python3 "$EVIDENCE" check-human "$TMP/current-ledger.json" \
  --review "$TMP/human-approved.json" --head "$HEAD_SHA" \
  | grep -Fq "PASS human review"
python3 "$EVIDENCE" check-human "$TMP/current-ledger.json" \
  --review "$TMP/human-bypass.json" --head "$HEAD_SHA" \
  | grep -Fq "PASS human review bypass"
if python3 "$EVIDENCE" check-human "$TMP/current-ledger.json" \
  --review "$TMP/human-stale.json" --head "$HEAD_SHA" \
  >"$TMP/human-stale.out" 2>&1; then
  echo "FAIL: stale human review passed" >&2
  exit 1
fi
grep -Fq "stale head" "$TMP/human-stale.out"
if python3 "$EVIDENCE" check-human "$TMP/current-ledger.json" \
  --review "$TMP/human-wrong-base.json" --head "$HEAD_SHA" \
  >"$TMP/human-base.out" 2>&1; then
  echo "FAIL: wrong-base human review passed" >&2
  exit 1
fi
grep -Fq "stale base" "$TMP/human-base.out"
for text in "READY_FOR_HUMAN_REVIEW" "check-human" "exact base..head" \
  "may not approve on the human's behalf"; do
  grep -Fq "$text" "$FINISH" || { echo "FAIL: finishing workflow missing $text" >&2; exit 1; }
done

python3 "$ROUTER" "$TMP/route.json" >"$TMP/route.out"
grep -Fq '"next_skill": "writing-plans"' "$TMP/route.out"
if python3 "$ROUTER" "$TMP/invalid-route.json" >"$TMP/invalid-route.out" 2>&1; then
  echo "FAIL: inconsistent workflow state passed" >&2
  exit 1
fi
grep -Fq "design cannot advance before product_contract" "$TMP/invalid-route.out"
grep -Fq "workflow-route.py" "$USING"

python3 - "$ROUTER" "$TMP" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

router, target = Path(sys.argv[1]), Path(sys.argv[2])
valid = {
    "schema_version": 1,
    "research": "complete",
    "product_contract": "approved",
    "design": "approved",
    "stress_test": "approved",
    "plan": "approved",
    "execution": "complete",
    "acceptance": "pass",
    "human_review": "approved",
}
cases = [
    ("product_contract", "research", {"research": "missing"}),
    ("design", "product_contract", {"product_contract": "missing"}),
    ("stress_test", "design", {"design": "missing"}),
    ("plan", "stress_test", {"stress_test": "missing"}),
    ("execution", "plan", {"plan": "missing"}),
    ("acceptance", "execution", {"execution": "not_started"}),
    ("human_review", "acceptance", {"acceptance": "not_started"}),
]
for phase, predecessor, mutation in cases:
    state = dict(valid)
    state.update(mutation)
    path = target / f"invalid-{phase}.json"
    path.write_text(json.dumps(state))
    result = subprocess.run(
        [sys.executable, str(router), str(path)],
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode != 0, (phase, result.stdout)
    assert f"{phase} cannot advance before {predecessor}" in result.stderr
PY

grep -Fq "workflow-metrics.py compare" "$WRITING"
python3 "$METRICS" snapshot --output "$TMP/metrics.json" >/dev/null
python3 "$METRICS" compare --baseline "$BASELINE" --candidate "$TMP/metrics.json" \
  >/dev/null

python3 "$RUNNER" --scenario "$SCENARIO" --provider fake --runs 2 \
  --max-runs 5 --concurrency 2 --evidence-dir "$TMP/research-evidence" \
  >"$TMP/research-scenario.json" 2>"$TMP/research-scenario.err"
python3 - "$TMP/research-scenario.json" "$TMP/research-scenario.err" <<'PY'
import json
import shutil
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text())
assert report["passed"] is True
assert report["aggregate"]["candidate_mean"] >= 0.9
assert report["aggregate"]["candidate_mean"] > report["aggregate"]["control_mean"]
assert set(report["samples"][0]["candidate"]["result"]["rubric_scores"]) == {
    "solution_neutral_questions",
    "fresh_observer_context",
    "current_state_only",
    "decision_aware_synthesis_separate",
}
raw = Path(sys.argv[2]).read_text().strip().split("=", 1)[1]
shutil.rmtree(raw)
PY

echo "PASS: human-owned research-plan-implement contract"
