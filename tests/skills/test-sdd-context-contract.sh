#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$ROOT/skills/subagent-driven-development/scripts/sdd-manifest.py"
FIXTURES="$ROOT/tests/fixtures/sdd-manifests"
SKILL="$ROOT/skills/subagent-driven-development/SKILL.md"
PROMPT="$ROOT/skills/subagent-driven-development/implementer-prompt.md"
CODEX_REFERENCE="$ROOT/skills/subagent-driven-development/references/codex-mode.md"
RUNNER="$ROOT/scripts/skill-microtest.py"
SCENARIO="$ROOT/tests/skill-microtests/scenarios/sdd-context-preflight.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PYTHONPYCACHEPREFIX="$TMP/pycache"

VALID="$TMP/valid-v2.json"
python3 - "$FIXTURES/valid.json" "$VALID" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text())
manifest["workflow_version"] = "0.15.0"
manifest["execution_epoch"] = {
    "epoch_id": "e" * 64,
    "status": "approved",
    "graph_sha256": manifest["graph_hash"],
}
manifest["design_seams"] = ["SEAM-CONTEXT"]
manifest["risk_boundaries"] = ["evidence"]
manifest["integration_owner"] = "controller"
manifest["integration_seam_id"] = None
manifest["verification_commands"] = [
    {"tier":"task", "command":"bash tests/skills/test-sdd-context-contract.sh"}
]
manifest["generated_write_set"] = [manifest["report_path"]]
manifest["speculative_dependency_commits"] = []
manifest["write_scope_amendments"] = []
scope = {
    "allowed_write_set": sorted(manifest["allowed_write_set"]),
    "generated_write_set": sorted(manifest["generated_write_set"]),
}
manifest["write_scope_hash"] = hashlib.sha256(
    json.dumps(scope, sort_keys=True, separators=(",", ":")).encode()
).hexdigest()
contract_fields = (
    "task_id", "workflow_version", "graph_hash", "governing_artifacts",
    "execution_epoch", "design_seams", "risk_boundaries",
    "integration_owner", "integration_seam_id",
    "outcome_ids", "base_commit", "reviewed_dependency_commits", "speculative_dependency_commits", "worktree",
    "allowed_write_set", "generated_write_set", "write_scope_hash",
    "write_scope_amendments", "prohibited_paths", "allocated_resources",
    "verification_commands", "known_conflicts",
)
payload = {field: manifest.get(field) for field in contract_fields}
manifest["contract_hash"] = hashlib.sha256(
    json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
).hexdigest()
target = Path(sys.argv[2])
target.write_text(json.dumps(manifest))
missing_outcomes = json.loads(json.dumps(manifest))
missing_outcomes["outcome_ids"] = []
(target.parent / "missing-outcomes.json").write_text(json.dumps(missing_outcomes))
conflicting_authority = json.loads(json.dumps(manifest))
conflicting_authority["governing_artifacts"].append({
    "path": conflicting_authority["governing_artifacts"][0]["path"],
    "revision": "d" * 64,
})
(target.parent / "conflicting-authority.json").write_text(json.dumps(conflicting_authority))
invalid_tier = json.loads(json.dumps(manifest))
invalid_tier["verification_commands"] = [{"tier":"broad", "command":"bash tests/all.sh"}]
(target.parent / "invalid-tier.json").write_text(json.dumps(invalid_tier))
release_tier = json.loads(json.dumps(manifest))
release_tier["verification_commands"] = [{"tier":"release", "command":"bash tests/all.sh"}]
(target.parent / "release-tier.json").write_text(json.dumps(release_tier))
missing_sensitivity = json.loads(json.dumps(manifest))
missing_sensitivity["risk_boundaries"] = ["authority"]
(target.parent / "missing-sensitivity.json").write_text(json.dumps(missing_sensitivity))
controller_integration = json.loads(json.dumps(manifest))
controller_integration["verification_commands"] = [
    {"tier":"integration", "command":"bash tests/integration.sh"}
]
(target.parent / "controller-integration.json").write_text(json.dumps(controller_integration))
false_reviewed = json.loads(json.dumps(manifest))
false_reviewed["speculative_dependency_commits"] = [{"task_id":"dep-a","commit":"2"*40,"frozen_interface":"API-A","disjoint_resources":True,"discard_files":1,"rebase_commits":1}]
false_reviewed["reviewed_dependency_commits"] = ["2"*40]
(target.parent / "false-reviewed.json").write_text(json.dumps(false_reviewed))
PY

python3 -m py_compile "$VALIDATOR"
python3 "$VALIDATOR" validate "$VALID" | tee "$TMP/valid.out"
grep -Fq "valid manifest: beads-superpowers-d3g" "$TMP/valid.out"
python3 - "$VALID" <<'PY'
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
  python3 "$VALIDATOR" validate "$TMP/missing-outcomes.json"
expect_failure conflicting-authority governing_artifacts \
  python3 "$VALIDATOR" validate "$TMP/conflicting-authority.json"
expect_failure invalid-tier verification_commands \
  python3 "$VALIDATOR" validate "$TMP/invalid-tier.json"
expect_failure release-tier "release verification belongs to the epic controller" \
  python3 "$VALIDATOR" validate "$TMP/release-tier.json"
expect_failure missing-sensitivity "sensitivity verification" \
  python3 "$VALIDATOR" validate "$TMP/missing-sensitivity.json"
expect_failure controller-integration "task-owned integration seam" \
  python3 "$VALIDATOR" validate "$TMP/controller-integration.json"
expect_failure false-reviewed "reviewed and speculative" \
  python3 "$VALIDATOR" validate "$TMP/false-reviewed.json"

python3 - "$VALID" "$TMP" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text())
target = Path(sys.argv[2])
missing_outcomes = json.loads(json.dumps(source))
missing_outcomes["outcome_ids"] = []
(target / "missing-outcomes.json").write_text(json.dumps(missing_outcomes))
conflicting_authority = json.loads(json.dumps(source))
conflicting_authority["governing_artifacts"].append({
    "path": conflicting_authority["governing_artifacts"][0]["path"],
    "revision": "d" * 64,
})
(target / "conflicting-authority.json").write_text(json.dumps(conflicting_authority))
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
    "workflow_version": "0.16.0",
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

prefix_overlap = json.loads(json.dumps(source))
prefix_overlap["prohibited_paths"] = ["skills/subagent-driven-development"]
(target / "prefix-overlap.json").write_text(json.dumps(prefix_overlap))

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

python3 "$VALIDATOR" bind --identity "$TMP/identity.json" --manifest "$VALID"
python3 "$VALIDATOR" bind --identity "$TMP/correction.json" --manifest "$VALID"
for field in task_id contract_hash base_commit worktree workflow_version graph_hash; do
  expect_failure "changed-$field" "identity:$field" \
    python3 "$VALIDATOR" bind --identity "$TMP/changed-$field.json" --manifest "$VALID"
done
expect_failure cross-task-followup identity:task_id \
  python3 "$VALIDATOR" bind --identity "$FIXTURES/cross-task-followup.json" --manifest "$VALID"
expect_failure untrusted governing_artifacts \
  python3 "$VALIDATOR" validate "$TMP/untrusted.json"
expect_failure prefix-overlap prohibited_paths \
  python3 "$VALIDATOR" validate "$TMP/prefix-overlap.json"

for platform in codex claude opencode; do
  python3 "$VALIDATOR" validate "$TMP/platform-$platform.json"
done

PREPARED="$TMP/prepared.json"
python3 - "$ROOT/tests/fixtures/graph-plans/valid-vertical.json" "$TMP/prepared.graph.json" "$TMP/prepared.epoch.json" <<'PY'
import hashlib, json, sys
from pathlib import Path
source=json.loads(Path(sys.argv[1]).read_text())
for node in source["nodes"]:
    if node.get("type") != "task":
        continue
    seam = "SEAM-APPROVAL" if node["key"] == "t1" else "SEAM-EVIDENCE"
    risks = "authority, persistence" if node["key"] == "t1" else "evidence"
    node["description"]=node["description"].replace(
        "- Why this slice exists:",
        f"- Design seams consumed: {seam}.\n- Complexity boundaries: {risks}.\n- Why this slice exists:",
    )
    node["description"]=node["description"].replace(
        "## Implementation Notes",
        f"- Owner: task.\n- Seam ID: {seam}.\n\n## Implementation Notes",
    )
graph_path=Path(sys.argv[2])
graph_path.write_text(json.dumps(source))
graph_sha=hashlib.sha256(graph_path.read_bytes()).hexdigest()
epoch={
  "schema_version":1,"epoch_id":"e"*64,"status":"approved","approved_at":"2026-07-30T00:00:00Z",
  "dirty_reason":None,"graph":{"path":"prepared.graph.json","sha256":graph_sha},
  "artifacts":[],"seam_catalog":{"path":"seams.json","sha256":"f"*64},
  "seams":[
    {"id":"SEAM-APPROVAL","high_risk_boundaries":["authority","persistence"]},
    {"id":"SEAM-EVIDENCE","high_risk_boundaries":["evidence"]}
  ],"unresolved_decisions":[]
}
Path(sys.argv[3]).write_text(json.dumps(epoch))
PY
python3 "$VALIDATOR" prepare \
  --graph "$TMP/prepared.graph.json" --epoch "$TMP/prepared.epoch.json" --task-key t1 \
  --task-id beads-superpowers-prepared \
  --base-commit 1111111111111111111111111111111111111111 \
  --worktree "$TMP/worktree" \
  --governing-artifact docs/product/approval-product-contract.md=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  --governing-artifact docs/specs/approval-design.md=cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc \
  --reviewed-dependency 2222222222222222222222222222222222222222 \
  --speculative-dependency '{"task_id":"dep-b","commit":"3333333333333333333333333333333333333333","frozen_interface":"APPROVAL-API","disjoint_resources":true,"discard_files":1,"rebase_commits":1}' \
  --prohibited .env --verify "focused::pytest tests/test_approval.py" \
  --verify "sensitivity::pytest tests/test_approval.py -k denied" \
  --verify "integration::pytest tests/test_approval.py" \
  --model-requested codex-5 --model-effective codex-5 --model-control explicit \
  --capability-tier isolated --context-mode isolated \
  --report-path .internal/sdd/prepared-report.md --output "$PREPARED"
python3 "$VALIDATOR" validate "$PREPARED"
python3 - "$PREPARED" <<'PY'
import json, sys
from pathlib import Path
manifest=json.loads(Path(sys.argv[1]).read_text())
assert manifest["workflow_version"] == "0.15.0"
assert manifest["execution_epoch"]["status"] == "approved"
assert manifest["design_seams"] == ["SEAM-APPROVAL"]
assert manifest["risk_boundaries"] == ["authority", "persistence"]
assert manifest["integration_owner"] == "task"
assert manifest["integration_seam_id"] == "SEAM-APPROVAL"
assert manifest["allowed_write_set"] == ["src/approval.py", "tests/test_approval.py"]
assert manifest["generated_write_set"] == [".internal/sdd/prepared-report.md"]
assert len(manifest["write_scope_hash"]) == 64
assert manifest["write_scope_amendments"] == []
assert manifest["allocated_resources"]["exclusive"] == ["approval command contract"]
assert manifest["verification_commands"] == [
  {"tier":"focused","command":"pytest tests/test_approval.py"},
  {"tier":"sensitivity","command":"pytest tests/test_approval.py -k denied"},
  {"tier":"integration","command":"pytest tests/test_approval.py"}
]
assert manifest["speculative_dependency_commits"] == [{"task_id":"dep-b","commit":"3"*40,"frozen_interface":"APPROVAL-API","disjoint_resources":True,"discard_files":1,"rebase_commits":1}]
PY

mkdir -p "$TMP/repo/src" "$TMP/repo/tests"
git -C "$TMP/repo" init -q
git -C "$TMP/repo" config user.name test
git -C "$TMP/repo" config user.email test@example.com
printf 'base\n' >"$TMP/repo/src/approval.py"
printf 'base\n' >"$TMP/repo/tests/test_approval.py"
git -C "$TMP/repo" add .
git -C "$TMP/repo" commit -qm base
BASE=$(git -C "$TMP/repo" rev-parse HEAD)
printf 'allowed\n' >>"$TMP/repo/src/approval.py"
git -C "$TMP/repo" commit -qam allowed
HEAD=$(git -C "$TMP/repo" rev-parse HEAD)
python3 "$VALIDATOR" check-diff --manifest "$PREPARED" --repo "$TMP/repo" --base "$BASE" --head "$HEAD"
printf 'forbidden\n' >"$TMP/repo/forbidden.txt"
git -C "$TMP/repo" add forbidden.txt
git -C "$TMP/repo" commit -qm forbidden
BAD_HEAD=$(git -C "$TMP/repo" rev-parse HEAD)
expect_failure undeclared-diff allowed_write_set \
  python3 "$VALIDATOR" check-diff --manifest "$PREPARED" --repo "$TMP/repo" --base "$BASE" --head "$BAD_HEAD"

AMENDED="$TMP/amended.json"
python3 "$VALIDATOR" amend --manifest "$PREPARED" \
  --graph "$ROOT/tests/fixtures/graph-plans/valid-vertical.json" --task-key t1 \
  --add-path docs/approval-notes.md --rationale "review requires task-owned operator evidence" \
  --output "$AMENDED"
python3 "$VALIDATOR" validate "$AMENDED"
python3 - "$PREPARED" "$AMENDED" <<'PY'
import json, sys
from pathlib import Path
before=json.loads(Path(sys.argv[1]).read_text())
after=json.loads(Path(sys.argv[2]).read_text())
assert after["contract_hash"] != before["contract_hash"]
assert after["write_scope_hash"] != before["write_scope_hash"]
assert after["write_scope_amendments"] == [{
    "path":"docs/approval-notes.md",
    "rationale":"review requires task-owned operator evidence",
    "overlaps":[],
    "status":"resolved",
}]
PY
expect_failure overlapping-amendment "overlaps task t2" \
  python3 "$VALIDATOR" amend --manifest "$PREPARED" \
    --graph "$ROOT/tests/fixtures/graph-plans/valid-vertical.json" --task-key t1 \
    --add-path tests/test_approval_outcome.py --rationale "would cross task ownership" \
    --output "$TMP/overlap.json"

for reference in context-lifecycle scheduling review-evidence; do
  test -f "$ROOT/skills/subagent-driven-development/references/$reference.md" || {
    echo "FAIL: missing SDD reference $reference.md" >&2; exit 1;
  }
done

test -f "$CODEX_REFERENCE" || {
  echo "FAIL: missing SDD Codex-mode reference" >&2
  exit 1
}
for text in "default mode" "codex mode" "Claude Code" "explicitly" "unavailable" \
  "[references/codex-mode.md](references/codex-mode.md)"; do
  grep -Fqi "$text" "$SKILL" || {
    echo "FAIL: SDD mode routing missing $text" >&2
    exit 1
  }
done
if grep -Fq 'codex exec' "$SKILL"; then
  echo "FAIL: Codex branch leaked into the SDD common path" >&2
  exit 1
fi
for text in "codex exec" "--disable multi_agent" "must not spawn" \
  "bd worktree create" "bd worktree remove" ".internal/sdd/" \
  "Context Manifest" "controller owns Beads" "read-only" \
  "implementer-prompt.md" "last-message.md" "absolute" "worker transport" \
  "low | medium | high | xhigh | max" "single hardest" "task reviewers" \
  "transport artifacts" "not authoritative"; do
  grep -Fqi -- "$text" "$CODEX_REFERENCE" || {
    echo "FAIL: SDD Codex mode missing $text" >&2
    exit 1
  }
done
if grep -Eq -- '--output-schema|additionalProperties' "$CODEX_REFERENCE"; then
  echo "FAIL: unused structured-output schema guidance entered Codex mode" >&2
  exit 1
fi
if grep -Fq 'launch.json' "$CODEX_REFERENCE"; then
  echo "FAIL: Codex transport duplicates manifest-owned launch state" >&2
  exit 1
fi
if grep -Eq '(^|[^a-z])git worktree (add|remove)' "$CODEX_REFERENCE"; then
  echo "FAIL: SDD Codex mode uses raw git worktree lifecycle commands" >&2
  exit 1
fi

for text in CONTRACT_READY NEEDS_CONTEXT contract_hash outcome_ids allowed_write_set prohibited_paths "verification tiers" \
  "controller owns Beads" "task-specific skills" "scope and security" "DONE_WITH_CONCERNS"; do
  grep -Fqi "$text" "$PROMPT" || { echo "FAIL: implementer prompt missing $text" >&2; exit 1; }
done
for text in prepare check-diff amend write_scope_hash generated_write_set; do
  grep -Fqi "$text" "$SKILL" "$ROOT/skills/subagent-driven-development/references/context-lifecycle.md" || {
    echo "FAIL: SDD manifest workflow missing $text" >&2; exit 1;
  }
done
if grep -Fq "Allowed write set:" "$ROOT/skills/writing-plans/slice-contract-template.md"; then
  echo "FAIL: Slice Contract still duplicates the graph Files write source" >&2
  exit 1
fi
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
