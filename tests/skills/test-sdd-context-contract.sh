#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/skills/subagent-driven-development/scripts/sdd-manifest.py"
FIXTURES="$ROOT/tests/fixtures/sdd-manifests"
SKILL="$ROOT/skills/subagent-driven-development/SKILL.md"
PROMPT="$ROOT/skills/subagent-driven-development/implementer-prompt.md"
RUNNER="$ROOT/scripts/skill-microtest.py"
SCENARIO="$ROOT/tests/skill-microtests/scenarios/sdd-context-preflight.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PYTHONPYCACHEPREFIX="$TMP/pycache"

python3 -m py_compile "$VALIDATOR"
python3 "$VALIDATOR" validate "$FIXTURES/valid.json" | tee "$TMP/valid.out"
grep -Fq "valid manifest: beads-superpowers-d3g" "$TMP/valid.out"
python3 - "$FIXTURES/valid.json" <<'PY'
import json, sys
from pathlib import Path
manifest = json.loads(Path(sys.argv[1]).read_text())
assert manifest["outcome_ids"] == [
    "SWF-CONTEXT-MANIFEST", "SWF-FRESH-CONTEXT",
    "SWF-CROSS-PLATFORM", "SWF-TOKEN-BUDGET",
]
PY

expect_failure() {
  local name="$1" field="$2"
  shift 2
  if "$@" >"$TMP/$name.out" 2>&1; then
    echo "FAIL: $name unexpectedly passed" >&2
    exit 1
  fi
  grep -Fq "$field" "$TMP/$name.out" || { cat "$TMP/$name.out" >&2; exit 1; }
}

expect_failure missing-outcomes outcome_ids \
  python3 "$VALIDATOR" validate "$FIXTURES/missing-outcomes.json"
expect_failure conflicting-authority governing_artifacts \
  python3 "$VALIDATOR" validate "$FIXTURES/conflicting-authority.json"

python3 - "$FIXTURES/valid.json" "$TMP" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text())
target = Path(sys.argv[2])
identity_fields = (
    "task_id", "contract_hash", "base_commit", "worktree",
    "workflow_version", "graph_hash",
)
identity = {field: source[field] for field in identity_fields}
(target / "identity.json").write_text(json.dumps(identity))
identity["correction_lineage"] = ["review-round-1"]
(target / "correction.json").write_text(json.dumps(identity))

changes = {
    "task_id": "beads-superpowers-other",
    "contract_hash": "f" * 64,
    "base_commit": "3" * 40,
    "worktree": "/tmp/superbeads-task-other",
    "workflow_version": "0.13.0",
    "graph_hash": "d" * 64,
}
for field, value in changes.items():
    changed = {key: source[key] for key in identity_fields}
    changed[field] = value
    (target / f"changed-{field}.json").write_text(json.dumps(changed))

untrusted = dict(source)
untrusted["governing_artifacts"] = [
    {"path": "docs/specs/workflow-design.md", "revision": "main"}
]
(target / "untrusted.json").write_text(json.dumps(untrusted))

platforms = {
    "codex": ("codex-5", "codex-5", "explicit", "isolated", "isolated"),
    "claude": (None, "claude-sonnet", "inherited", "host-limited", "host-limited"),
    "opencode": (None, None, "unavailable", "host-limited", "host-limited"),
}
for name, values in platforms.items():
    variant = dict(source)
    for key, value in zip(
        ("model_requested", "model_effective", "model_control", "capability_tier", "context_mode"),
        values,
    ):
        variant[key] = value
    (target / f"platform-{name}.json").write_text(json.dumps(variant))
PY

python3 "$VALIDATOR" bind --identity "$TMP/identity.json" --manifest "$FIXTURES/valid.json"
python3 "$VALIDATOR" bind --identity "$TMP/correction.json" --manifest "$FIXTURES/valid.json"
for field in task_id contract_hash base_commit worktree workflow_version graph_hash; do
  expect_failure "changed-$field" "identity:$field" \
    python3 "$VALIDATOR" bind --identity "$TMP/changed-$field.json" --manifest "$FIXTURES/valid.json"
done
expect_failure cross-task-followup identity:task_id \
  python3 "$VALIDATOR" bind --identity "$FIXTURES/cross-task-followup.json" --manifest "$FIXTURES/valid.json"
expect_failure untrusted governing_artifacts \
  python3 "$VALIDATOR" validate "$TMP/untrusted.json"

for platform in codex claude opencode; do
  python3 "$VALIDATOR" validate "$TMP/platform-$platform.json"
done

for reference in context-lifecycle scheduling review-evidence; do
  test -f "$ROOT/skills/subagent-driven-development/references/$reference.md" || {
    echo "FAIL: missing SDD reference $reference.md" >&2; exit 1;
  }
done

for text in CONTRACT_READY NEEDS_CONTEXT contract_hash outcome_ids allowed_write_set prohibited_paths \
  "controller owns Beads" "task-specific skills" "scope and security" "DONE_WITH_CONCERNS"; do
  grep -Fqi "$text" "$PROMPT" || { echo "FAIL: implementer prompt missing $text" >&2; exit 1; }
done
if grep -Eq 'bd (update|create|close|comment)' "$PROMPT"; then
  echo "FAIL: implementer prompt contains Beads mutation" >&2; exit 1
fi
if grep -Fq 'LSP is your DEFAULT' "$PROMPT"; then
  echo "FAIL: implementer prompt mandates universal LSP traversal" >&2; exit 1
fi
grep -Eiq 'unexpected failure.*superbeads:systematic-debugging|superbeads:systematic-debugging.*unexpected failure' "$PROMPT" || {
  echo "FAIL: debugging skill is not conditional on an unexpected failure" >&2; exit 1;
}

for text in "./outcome-reviewer-prompt.md" "only if user requested draft PR/branch disposition" \
  "Agent-Filed Bead Discipline" "CONTRACT_READY" "NEEDS_CONTEXT"; do
  grep -Fq "$text" "$SKILL" || { echo "FAIL: SDD spine missing $text" >&2; exit 1; }
done

skill_words=$(wc -w <"$SKILL" | tr -d ' ')
prompt_words=$(wc -w <"$PROMPT" | tr -d ' ')
if (( skill_words >= 4485 || prompt_words >= 1243 )); then
  echo "FAIL: SDD common path did not shrink: skill=$skill_words prompt=$prompt_words" >&2
  exit 1
fi

python3 "$RUNNER" --scenario "$SCENARIO" --provider fake --runs 2 \
  --max-runs 5 --concurrency 2 --evidence-dir "$TMP/evidence" \
  >"$TMP/scenario.json" 2>"$TMP/scenario.err"
python3 - "$TMP/scenario.json" "$TMP/scenario.err" <<'PY'
import json
import shutil
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text())
assert report["passed"] is True
assert report["aggregate"]["candidate_mean"] >= 0.9
assert set(report["samples"][0]["candidate"]["result"]["rubric_scores"]) == {
    "trusted_manifest", "pre_edit_handshake", "fresh_identity",
    "bounded_context", "platform_truth",
}
candidate_trace = report["samples"][0]["candidate"]["result"]["summary"]
control_trace = report["samples"][0]["control"]["result"]["summary"]
assert candidate_trace.index("CONTRACT_READY") < candidate_trace.index("EDIT")
assert control_trace.index("EDIT") < control_trace.index("CONTRACT_READY")
raw = Path(sys.argv[2]).read_text().strip().split("=", 1)[1]
shutil.rmtree(raw)
PY

echo "PASS: SDD trusted context contract"
