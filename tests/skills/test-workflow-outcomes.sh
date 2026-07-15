#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$ROOT/tests/fixtures/integration/workflow-outcomes.json"
SCENARIO="$ROOT/tests/skill-microtests/scenarios/end-to-end-workflow.json"
MODE="${1:---validate}"

python3 - "$ROOT" "$FIXTURE" "$SCENARIO" "$MODE" <<'PY'
import importlib.util
import json
import re
import sys
from pathlib import Path

root, fixture_path, scenario_path, mode = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]
fixture = json.loads(fixture_path.read_text())
scenario = json.loads(scenario_path.read_text())
runner_path = root / "scripts/skill-microtest.py"
spec = importlib.util.spec_from_file_location("skill_microtest", runner_path)
runner = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(runner)
runner.validate_scenario(scenario)
runner.validate_candidate_skill_paths(scenario["candidate_skill_paths"], root)

campaign = fixture["campaign"]
assert campaign["deterministic"] == "PASS"
assert campaign["install_shape"] == "CODEX_ONLY_PASS"
assert "Codex" in campaign["install_shape_reason"]
assert campaign["just_check"] in {"PASS", "NOT_RUN"}
if campaign["just_check"] == "NOT_RUN":
    assert campaign["just_check_reason"]
assert campaign["whole_change_review"] == "SELF_REVIEW_ONLY"
assert "inline" in campaign["whole_change_review_reason"].lower()
assert campaign["release_outcome_gate"] == "OPEN"
assert campaign["claude_live"] == "NOT_RUN"
assert "forbidden" in campaign["claude_live_reason"].lower()
assert campaign["codex_live"] in {"PASS", "FAIL", "UNTESTED"}
if campaign["codex_live"] == "UNTESTED":
    assert "authorization" in campaign["codex_live_reason"].lower()

evidence = fixture["deterministic_evidence"]
assert set(evidence["elapsed_seconds"]) == {
    "guards", "contracts", "hooks", "manifests", "codex_install_shape",
    "scheduler", "evidence_gate", "outcome_contract",
}
assert all(value >= 0 for value in evidence["elapsed_seconds"].values())
assert evidence["graph"] == {
    "declared_tasks": 12,
    "bead_issues": 14,
    "closed_bead_issues": 13,
    "ready_fronts": 10,
    "max_parallelism": 2,
}
metrics = evidence["metrics"]
assert metrics["incremental_product_definition_words"] == (
    metrics["product_discovery_words"] - metrics["accepted_contract_words"]
)
assert metrics["matched_legacy_words"] <= 14418
assert metrics["description_bytes"] <= 3253
assert metrics["rendered_lifecycle_bytes"] <= 3878

ids = {
    "SWF-PRODUCT-CONTRACT", "SWF-VERTICAL-SLICE", "SWF-CONTEXT-MANIFEST",
    "SWF-FRESH-CONTEXT", "SWF-ROLLING-FLOW", "SWF-EVIDENCE-GATE",
    "SWF-TOKEN-BUDGET", "SWF-CROSS-PLATFORM", "SWF-ADVERSARIAL-COVERAGE",
}
columns = {
    "acceptance_id", "implementation_task", "earliest_seam", "evidence_class",
    "commit", "contract_revision", "environment", "fixture_revision", "result", "artifact",
}
allowed_results = {"PASS", "FAIL", "BLOCKED", "UNTESTED", "SKIPPED", "NOT_RUN"}
records = fixture["outcomes"]
assert len(records) == len(ids)
assert {record["acceptance_id"] for record in records} == ids
assert len({record["acceptance_id"] for record in records}) == len(records)
for record in records:
    assert set(record) == columns, (record["acceptance_id"], set(record) ^ columns)
    assert record["result"] in allowed_results
    assert re.fullmatch(r"[0-9a-f]{7,40}", record["commit"])
    assert re.fullmatch(r"0\.12\.0:[0-9a-f]{64}", record["contract_revision"])
    assert record["fixture_revision"]
    if record["result"] == "PASS":
        assert (root / record["artifact"]).is_file(), record

platform_fields = {
    "host", "model_requested", "model_effective", "model_control",
    "capability_tier", "context_mode", "fallback_reason", "live_tested",
}
platforms = fixture["platforms"]
assert {record["host"] for record in platforms} == {"claude", "codex", "opencode"}
for record in platforms:
    assert set(record) == platform_fields
    assert record["model_control"] in {"requested", "effective", "inherited", "unavailable"}
    assert record["capability_tier"] in {"isolated", "host-limited"}
    assert record["context_mode"] in {"isolated", "host-limited"}
claude = next(record for record in platforms if record["host"] == "claude")
assert claude["live_tested"] is False
assert "forbidden" in claude["fallback_reason"].lower()

assert scenario["id"] == "end-to-end-workflow"
assert {criterion["id"] for criterion in scenario["rubric"]["criteria"]} == ids
for path in scenario["candidate_skill_paths"]:
    resolved = (root / path).resolve()
    resolved.relative_to(root.resolve())
    assert resolved.is_file(), path

open_results = [record for record in records if record["result"] != "PASS"]
if mode == "--require-pass" and open_results:
    print("workflow outcome gate is open:", file=sys.stderr)
    for record in open_results:
        print(f"- {record['acceptance_id']}: {record['result']}", file=sys.stderr)
    raise SystemExit(1)
assert mode in {"--validate", "--require-pass"}
print(f"workflow outcomes: {len(records) - len(open_results)} PASS, {len(open_results)} open")
PY

echo "PASS: integrated workflow outcome contract"
