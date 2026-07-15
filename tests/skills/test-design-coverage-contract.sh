#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BRAIN="$ROOT/skills/brainstorming/SKILL.md"
QUESTIONS="$ROOT/skills/brainstorming/question-coverage.md"
STRESS="$ROOT/skills/stress-test/SKILL.md"
MATRIX="$ROOT/skills/stress-test/coverage-matrix.md"
RUNNER="$ROOT/scripts/skill-microtest.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

require_text() {
  local file="$1" text="$2"
  grep -Fq "$text" "$file" || {
    echo "FAIL: ${file#$ROOT/} missing: $text" >&2
    exit 1
  }
}

require_text "$BRAIN" "product contract path and revision"
require_text "$BRAIN" "Do not ask the user to restate"
require_text "$BRAIN" "up to three independent"
require_text "$BRAIN" "dependency-changing decisions remain serial"
require_text "$BRAIN" "route to product-definition"
require_text "$BRAIN" "coverage summary"
require_text "$BRAIN" "unresolved high-risk"
require_text "$BRAIN" "Agent-Filed Bead Discipline"
require_text "$QUESTIONS" "Observed evidence"
require_text "$QUESTIONS" "Affected outcome IDs"
require_text "$QUESTIONS" "Known product fact"

for column in Applicable Evidence "Question / recommendation" "Falsifying example" Resolution "Affected outcome IDs"; do
  require_text "$MATRIX" "$column"
done
require_text "$STRESS" "absent from the input artifact"
require_text "$STRESS" "falsifying example"
require_text "$STRESS" "up to three independent"
require_text "$STRESS" "dependency-changing decisions remain serial"
require_text "$STRESS" "no security surface — N/A"
require_text "$STRESS" "unresolved high-risk"

brain_words=$(wc -w <"$BRAIN" | tr -d ' ')
stress_words=$(wc -w <"$STRESS" | tr -d ' ')
if (( brain_words >= 3609 || stress_words >= 2030 )); then
  echo "FAIL: common paths did not shrink: brainstorming=$brain_words stress-test=$stress_words" >&2
  exit 1
fi

run_scenario() {
  local name="$1"
  local expected="$2"
  local scenario="$ROOT/tests/skill-microtests/scenarios/$name.json"
  local evidence="$TMP/$name-evidence"
  python3 "$RUNNER" --scenario "$scenario" --provider fake --runs 2 \
    --max-runs 5 --concurrency 2 --evidence-dir "$evidence" \
    >"$TMP/$name.json" 2>"$TMP/$name.err"
  python3 - "$TMP/$name.json" "$TMP/$name.err" "$expected" <<'PY'
import json
import shutil
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert report["passed"] is True
assert report["aggregate"]["candidate_mean"] >= 0.9
assert report["execution"]["provider_calls"] == 4
assert report["execution"]["max_observed_concurrency"] <= 2
assert set(report["samples"][0]["candidate"]["result"]["rubric_scores"]) == set(sys.argv[3].split(","))
raw_line = Path(sys.argv[2]).read_text(encoding="utf-8").strip()
shutil.rmtree(Path(raw_line.split("=", 1)[1]))
PY
}

run_scenario brainstorming-product-aware "no_repeat,evidence_questions,safe_batching,narrow_product_route"
run_scenario stress-test-novelty "applicability_matrix,novel_complication,falsifying_case,outcome_trace,security_evidence"

echo "PASS: product-aware design coverage contract"
