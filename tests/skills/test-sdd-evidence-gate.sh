#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECKER="$ROOT/skills/subagent-driven-development/scripts/sdd-evidence.py"
FIXTURES="$ROOT/tests/fixtures/sdd-evidence"
REFERENCE="$ROOT/skills/subagent-driven-development/references/review-evidence.md"
TASK_PROMPT="$ROOT/skills/subagent-driven-development/task-reviewer-prompt.md"
OUTCOME_PROMPT="$ROOT/skills/subagent-driven-development/outcome-reviewer-prompt.md"
VERIFY="$ROOT/skills/verification-before-completion/SKILL.md"
FINISH="$ROOT/skills/finishing-a-development-branch/SKILL.md"
RUNNER="$ROOT/scripts/skill-microtest.py"
SCENARIO="$ROOT/tests/skill-microtests/scenarios/sdd-review-correction.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PYTHONPYCACHEPREFIX="$TMP/pycache"

python3 -m py_compile "$CHECKER"
python3 "$CHECKER" check-task "$FIXTURES/pass.json" | tee "$TMP/pass-task.out"
python3 "$CHECKER" check-epic "$FIXTURES/pass.json" | tee "$TMP/pass-epic.out"
python3 "$CHECKER" check-dispatch "$FIXTURES/pass.json" | tee "$TMP/pass-dispatch.out"
grep -Fq "PASS task: TASK-A, TASK-B" "$TMP/pass-task.out"
grep -Fq "PASS epic: OUT-A" "$TMP/pass-epic.out"
grep -Fq "PASS dispatch" "$TMP/pass-dispatch.out"

expect_failure() {
  local command="$1" fixture="$2" output
  output="$TMP/$command-$fixture.out"
  if python3 "$CHECKER" "$command" "$FIXTURES/$fixture.json" >"$output" 2>&1; then
    echo "FAIL: $command accepted $fixture" >&2; exit 1
  fi
  shift 2
  for expected in "$@"; do
    grep -Fq "$expected" "$output" || { cat "$output" >&2; exit 1; }
  done
}

expect_failure check-task stale TASK-A TASK-B "stale commit"
expect_failure check-epic stale OUT-A "stale commit"
expect_failure check-task substituted TASK-A TASK-B "substituted evidence class"
expect_failure check-epic substituted OUT-A "substituted evidence class"
expect_failure check-task blocked TASK-A TASK-B BLOCKED UNTESTED
expect_failure check-epic blocked OUT-A FAIL
expect_failure check-task two-rounds "diagnostic required" amend-contract split-slice resolve-product-decision adjudicate-reviewer
expect_failure check-dispatch two-rounds "dispatch disallowed" "two failed review rounds"

python3 - "$FIXTURES/two-rounds.json" "$TMP" <<'PY'
import json, sys
from pathlib import Path
source=json.loads(Path(sys.argv[1]).read_text())
fixed=json.loads(json.dumps(source))
fixed["diagnostic"]={"result":"split-slice","strategy":"create a new vertical slice with explicit cache lifetime","next_task_id":"task-cache-lifetime","next_contract_hash":None,"dispatch_allowed":False}
Path(sys.argv[2],"diagnosed.json").write_text(json.dumps(fixed))
reused=json.loads(json.dumps(fixed))
reused["review_rounds"][1]["reviewer_context_id"]=reused["review_rounds"][0]["reviewer_context_id"]
Path(sys.argv[2],"reused-reviewer.json").write_text(json.dumps(reused))
malformed=json.loads(json.dumps(fixed))
del malformed["review_rounds"][0]["findings"][0]["counterexample"]
Path(sys.argv[2],"malformed-finding.json").write_text(json.dumps(malformed))
empty_findings=json.loads(json.dumps(source))
empty_findings["review_rounds"]=[{"round":1,"result":"FAIL","reviewer_context_id":"fresh-empty-reviewer","findings":[]}]
Path(sys.argv[2],"empty-findings.json").write_text(json.dumps(empty_findings))
contradictory=json.loads(Path("tests/fixtures/sdd-evidence/pass.json").read_text())
conflict=json.loads(json.dumps(contradictory["evidence"][0])); conflict["result"]="FAIL"
contradictory["evidence"].append(conflict)
Path(sys.argv[2],"contradictory.json").write_text(json.dumps(contradictory))
PY
python3 "$CHECKER" check-task "$TMP/diagnosed.json" | grep -Fq "PASS task"
if python3 "$CHECKER" check-task "$TMP/reused-reviewer.json" >"$TMP/reused.out" 2>&1; then
  echo "FAIL: reused reviewer context passed" >&2; exit 1
fi
grep -Fq "fresh reviewer" "$TMP/reused.out"
if python3 "$CHECKER" check-task "$TMP/malformed-finding.json" >"$TMP/malformed.out" 2>&1; then
  echo "FAIL: malformed typed finding passed" >&2; exit 1
fi
grep -Fq "counterexample" "$TMP/malformed.out"
if python3 "$CHECKER" check-task "$TMP/empty-findings.json" >"$TMP/empty-findings.out" 2>&1; then
  echo "FAIL: failed review round without typed findings passed" >&2; exit 1
fi
grep -Fq "failed round requires typed findings" "$TMP/empty-findings.out"
if python3 "$CHECKER" check-task "$TMP/contradictory.json" >"$TMP/contradictory.out" 2>&1; then
  echo "FAIL: contradictory current evidence passed" >&2; exit 1
fi
grep -Fq "conflicting current results" "$TMP/contradictory.out"

for text in MANIFEST_FILE REPORT_FILE BASE_SHA HEAD_SHA DOMAIN_CAPSULE "acceptance_matrix" \
  finding_id severity acceptance_ids classification evidence invalidated_assumption correction counterexample contract_hash review_round \
  "fresh reviewer"; do
  grep -Fqi "$text" "$TASK_PROMPT" || { echo "FAIL: task reviewer prompt missing $text" >&2; exit 1; }
done
if grep -Eq 'bd (update|create|close|comment)' "$TASK_PROMPT"; then
  echo "FAIL: task reviewer owns Beads mutation" >&2; exit 1
fi
for text in "current commit" "contract hash" environment fixture "acceptance matrix" "fresh reviewer"; do
  grep -Fqi "$text" "$OUTCOME_PROMPT" || { echo "FAIL: outcome reviewer prompt missing $text" >&2; exit 1; }
done
for text in "two failed" amend-contract split-slice resolve-product-decision adjudicate-reviewer "fresh reviewer"; do
  grep -Fqi "$text" "$REFERENCE" || { echo "FAIL: review reference missing $text" >&2; exit 1; }
done
for text in "check-dispatch" focused task integration release prepare implement review correction merge release; do
  grep -Fqi "$text" "$REFERENCE" || { echo "FAIL: review reference missing $text" >&2; exit 1; }
done

for file in "$VERIFY" "$FINISH"; do
  grep -Fq "sdd-evidence.py" "$file" || { echo "FAIL: ${file#$ROOT/} bypasses evidence checker" >&2; exit 1; }
done
grep -Fq "check-task" "$VERIFY"
grep -Fq "check-task" "$FINISH"
grep -Fq "check-epic" "$FINISH"
grep -Fq "NO REQUIRED VERIFICATION MAY BE SUBSTITUTED" "$VERIFY"
grep -Fq "READY_FOR_CODE_REVIEW" "$FINISH"
grep -Fq "Open draft PR" "$FINISH"

verify_words=$(wc -w <"$VERIFY" | tr -d ' ')
finish_words=$(wc -w <"$FINISH" | tr -d ' ')
task_prompt_words=$(wc -w <"$TASK_PROMPT" | tr -d ' ')
if (( verify_words >= 1690 || finish_words >= 2214 || task_prompt_words >= 1272 )); then
  echo "FAIL: evidence paths did not shrink: verify=$verify_words finish=$finish_words task-prompt=$task_prompt_words" >&2
  exit 1
fi

python3 "$RUNNER" --scenario "$SCENARIO" --provider fake --runs 2 \
  --max-runs 5 --concurrency 2 --evidence-dir "$TMP/evidence" \
  >"$TMP/scenario.json" 2>"$TMP/scenario.err"
python3 - "$TMP/scenario.json" "$TMP/scenario.err" <<'PY'
import json, shutil, sys
from pathlib import Path
report=json.loads(Path(sys.argv[1]).read_text())
assert report["passed"] is True
assert report["aggregate"]["candidate_mean"] >= 0.9
assert set(report["samples"][0]["candidate"]["result"]["rubric_scores"]) == {"typed_findings","fresh_reviewer","bounded_correction","current_evidence","non_substitution"}
raw=Path(sys.argv[2]).read_text().strip().split("=",1)[1]
shutil.rmtree(raw)
PY

bash "$ROOT/tests/skills/test-outcome-acceptance-contract.sh"
echo "PASS: bounded review and acceptance evidence gate"
