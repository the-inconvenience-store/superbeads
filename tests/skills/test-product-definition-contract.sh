#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/scripts/validate-product-contract.py"
FIXTURES="$ROOT/tests/fixtures/product-contract"
SKILL="$ROOT/skills/product-definition/SKILL.md"
TEMPLATE="$ROOT/skills/product-definition/product-contract-template.md"
SCENARIO="$ROOT/tests/skill-microtests/scenarios/product-definition.json"
RUNNER="$ROOT/scripts/skill-microtest.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

expect_failure() {
  local label="$1" path="$2" section="$3"
  if python3 "$VALIDATOR" "$path" >"$TMP/$label.out" 2>&1; then
    echo "FAIL: $label unexpectedly passed" >&2
    exit 1
  fi
  grep -Fq "$path:$section:" "$TMP/$label.out" || {
    echo "FAIL: $label did not identify $section" >&2
    cat "$TMP/$label.out" >&2
    exit 1
  }
}

python3 "$VALIDATOR" "$FIXTURES/valid.md"

printf '%s\n' \
  'Product contract: Not applicable — formatter-only comment wrapping observed in generated test output; changes no user-visible behavior, durable business rule, workflow, terminology, or external interface.' \
  >"$TMP/legitimate-bypass.md"
python3 "$VALIDATOR" "$TMP/legitimate-bypass.md"

expect_failure invalid-bypass "$FIXTURES/invalid-bypass.md" Bypass
expect_failure unresolved "$FIXTURES/unresolved.md" Assumptions

python3 - "$FIXTURES/valid.md" "$TMP/owned-decision.md" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
Path(sys.argv[2]).write_text(
    source.replace("- Assumed: none.", "- Assumed: TBD; Decision owner: Sam"),
    encoding="utf-8",
)
PY
python3 "$VALIDATOR" "$TMP/owned-decision.md"

python3 - "$FIXTURES/valid.md" "$TMP/duplicate.md" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
row = "| SWF-PRODUCT-CONTRACT | Maintainer repeats the flow | Duplicate | Validator |\n"
Path(sys.argv[2]).write_text(source.replace("\n## Non-Goals", f"\n{row}\n## Non-Goals"), encoding="utf-8")
PY
expect_failure duplicate "$TMP/duplicate.md" "Outcome Trace"

python3 - "$FIXTURES/valid.md" "$TMP/unapproved.md" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
Path(sys.argv[2]).write_text(source.replace("Status: Approved", "Status: Draft"), encoding="utf-8")
PY
expect_failure unapproved "$TMP/unapproved.md" Approval

for heading in \
  "Goal" "Source Ledger" "Actors and Authority" \
  "Vocabulary and Domain Model" "Lifecycle and Invariants" \
  "Journeys and States" "Examples and Counterexamples" "Outcome Trace" \
  "Non-Goals and Decisions" "Assumptions" "Approval"; do
  grep -Fq "## $heading" "$TEMPLATE" || {
    echo "FAIL: template missing heading: $heading" >&2
    exit 1
  }
done

grep -Fq "Use when the user asks to establish" "$SKILL"
grep -Fq "optional supporting artifact" "$SKILL"
grep -Fq "do not invoke this skill" "$SKILL"
grep -Fq "Do not ask the user to repeat" "$SKILL"
grep -Fq "routes to brainstorming" "$SKILL"
grep -Fq "no user-visible behavior, durable business rule, workflow, terminology, or external interface" "$SKILL"

EVIDENCE="$TMP/evidence"
python3 "$RUNNER" --scenario "$SCENARIO" --provider replay --runs 5 \
  --max-runs 5 --concurrency 2 --evidence-dir "$EVIDENCE" \
  >"$TMP/first.json" 2>"$TMP/first.err"
python3 "$RUNNER" --scenario "$SCENARIO" --provider replay --runs 5 \
  --max-runs 5 --concurrency 2 --evidence-dir "$EVIDENCE" \
  >"$TMP/second.json" 2>"$TMP/second.err"
python3 - "$TMP/first.json" "$TMP/second.json" "$TMP/first.err" <<'PY'
import json
import shutil
import sys
from pathlib import Path

first = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
second = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
assert first["passed"] is True
assert first["aggregate"]["candidate_mean"] == 1.0
assert first["execution"]["provider_calls"] == 10
assert first["execution"]["max_observed_concurrency"] <= 2
assert second["cache"]["reused"] is True
assert second["execution"]["provider_calls"] == 0
identity = first["identity"]
assert identity["provider"] == "replay" and identity["model"] == "replay-v1"
assert all(identity[field] for field in ("skill_hash", "fixture_hash", "rubric_version"))
assert set(first["samples"][0]["candidate"]["result"]["rubric_scores"]) == {
    "actors", "authority", "lifecycle", "counterexamples", "stable_ids"
}
raw_line = Path(sys.argv[3]).read_text(encoding="utf-8").strip()
shutil.rmtree(Path(raw_line.split("=", 1)[1]))
PY

grep -Fq "product-definition" "$ROOT/install.sh"
python3 "$ROOT/scripts/check-skill-frontmatter.py"
bash "$ROOT/scripts/check-skill-count.sh"

echo "PASS: product-definition contract"
