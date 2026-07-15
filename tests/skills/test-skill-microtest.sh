#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$ROOT/scripts/skill-microtest.py"
SCENARIO="$ROOT/tests/skill-microtests/scenarios/writing-plans-horizontal-baseline.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 - "$RUNNER" "$TMP" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

runner_path = Path(sys.argv[1])
tmp = Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("skill_microtest", runner_path)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

root = tmp / "sandbox"
schema = tmp / "schema.json"
output = tmp / "last-message.json"
assert module.build_codex_argv(root, schema, output) == [
    "codex", "exec", "--ephemeral", "--ignore-user-config", "--ignore-rules",
    "--sandbox", "read-only", "--ask-for-approval", "never", "-C", str(root),
    "--output-schema", str(schema), "--output-last-message", str(output), "-",
]
assert module.build_claude_argv(root, schema, output) == [
    "claude", "--print", "--bare", "--tools", "", "--no-session-persistence",
    "--permission-mode", "dontAsk", "--output-format", "json",
    "--json-schema", str(schema),
]
assert module.provider_status("claude") == "not_live_tested"

allowed = tmp / "allowed"
allowed.mkdir()
(allowed / "ok.txt").write_text("sanitized fixture\n", encoding="utf-8")
outside = tmp / "outside.txt"
outside.write_text("outside\n", encoding="utf-8")
(allowed / "escape").symlink_to(outside)
assert module.validate_fixture_paths(["ok.txt"], allowed) == [(allowed / "ok.txt").resolve()]
for unsafe in ("../outside.txt", "escape"):
    try:
        module.validate_fixture_paths([unsafe], allowed)
    except module.MicrotestError as error:
        assert "escapes allowed fixture root" in str(error), str(error)
    else:
        raise AssertionError(f"unsafe fixture accepted: {unsafe}")

identity = {
    "scenario": "scenario-a", "skill_hash": "skill-a", "provider": "replay",
    "model": "replay-v1", "fixture_hash": "fixture-a",
    "rubric_version": "1", "runner_version": "1",
}
cache_path = tmp / "evidence.json"
cache_path.write_text(json.dumps({"identity": identity, "passed": True}), encoding="utf-8")
for field in identity:
    changed = dict(identity)
    changed[field] = f"changed-{field}"
    assert module.invalidation_reasons(identity, changed) == [f"{field}_changed"]
    cached, reasons = module.cache_state(cache_path, changed)
    assert cached is None
    assert reasons == [f"{field}_changed"]

source = runner_path.read_text(encoding="utf-8")
assert "shell=True" not in source
assert "os.environ.copy" not in source
PY

make_scenario() {
  local output="$1"
  local fixture_json="$2"
  local extra_json="${3:-}"
  python3 - "$SCENARIO" "$output" "$fixture_json" "$extra_json" <<'PY'
import json
import sys
from pathlib import Path

document = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
document["fixture_paths"] = json.loads(sys.argv[3])
if sys.argv[4]:
    document.update(json.loads(sys.argv[4]))
Path(sys.argv[2]).write_text(json.dumps(document), encoding="utf-8")
PY
}

expect_preflight_failure() {
  local label="$1"
  local pattern="$2"
  shift 2
  local evidence="$TMP/preflight-$label"
  if python3 "$RUNNER" "$@" --evidence-dir "$evidence" >"$TMP/$label.out" 2>&1; then
    echo "FAIL: $label passed preflight" >&2
    exit 1
  fi
  grep -Eq "$pattern" "$TMP/$label.out" || {
    echo "FAIL: $label did not report expected error" >&2
    cat "$TMP/$label.out" >&2
    exit 1
  }
  if [[ -d "$evidence/raw" ]] && find "$evidence/raw" -type f -print -quit | grep -q .; then
    echo "FAIL: $label executed a provider before failing" >&2
    exit 1
  fi
}

make_scenario "$TMP/traversal.json" '["../outside.txt"]'
expect_preflight_failure traversal 'escapes allowed fixture root' \
  --scenario "$TMP/traversal.json" --provider replay --runs 5 --max-runs 5 --concurrency 2

make_scenario "$TMP/secret.json" '["writing-plans/request.md"]' \
  '{"environment":{"API_TOKEN":"synthetic-marker"}}'
expect_preflight_failure secret 'secret-like environment input' \
  --scenario "$TMP/secret.json" --provider replay --runs 5 --max-runs 5 --concurrency 2

expect_preflight_failure provider 'invalid choice|unknown provider' \
  --scenario "$SCENARIO" --provider shell --runs 5 --max-runs 5 --concurrency 2
expect_preflight_failure run-cap 'exceed.*max-runs|run cap' \
  --scenario "$SCENARIO" --provider replay --runs 6 --max-runs 5 --concurrency 2
expect_preflight_failure concurrency 'concurrency.*maximum 2' \
  --scenario "$SCENARIO" --provider replay --runs 5 --max-runs 5 --concurrency 3
expect_preflight_failure cost-confirmation 'confirm-cost' \
  --scenario "$SCENARIO" --provider codex --runs 1 --max-runs 5 --concurrency 1 --max-cost-usd 1
expect_preflight_failure cost-cap 'max-cost-usd' \
  --scenario "$SCENARIO" --provider codex --runs 1 --max-runs 5 --concurrency 1 --confirm-cost --max-cost-usd 0

EVIDENCE="$TMP/replay-evidence"
python3 "$RUNNER" --scenario "$SCENARIO" --provider replay --runs 5 \
  --max-runs 5 --concurrency 2 --evidence-dir "$EVIDENCE" >"$TMP/replay-first.json"
python3 "$RUNNER" --scenario "$SCENARIO" --provider replay --runs 5 \
  --max-runs 5 --concurrency 2 --evidence-dir "$EVIDENCE" >"$TMP/replay-second.json"

python3 - "$TMP/replay-first.json" "$TMP/replay-second.json" "$EVIDENCE" "$TMP" <<'PY'
import json
import sys
from pathlib import Path

first_path, second_path, evidence, tmp = map(Path, sys.argv[1:])
first = json.loads(first_path.read_text(encoding="utf-8"))
second = json.loads(second_path.read_text(encoding="utf-8"))
assert first["cache"] == {"reused": False, "invalidation_reasons": ["no_passing_evidence"]}
assert first["execution"]["provider_calls"] == 10
assert len(first["samples"]) == 5
calls = [sample[variant] for sample in first["samples"] for variant in ("control", "candidate")]
assert len({call["sandbox_id"] for call in calls}) == 10
assert first["execution"]["max_observed_concurrency"] <= 2
assert first["aggregate"] == {
    "candidate_mean": 1.0, "candidate_variance": 0.0,
    "control_mean": 0.25, "control_variance": 0.0,
    "delta_mean": 0.75, "delta_variance": 0.0,
}
for call in calls:
    transcript = Path(call["raw_transcript"])
    assert not transcript.is_absolute()
    assert (evidence / transcript).is_file()
assert second["cache"] == {"reused": True, "invalidation_reasons": []}
assert second["execution"]["provider_calls"] == 0
assert second["aggregate"] == first["aggregate"]
durable = first_path.read_text(encoding="utf-8") + second_path.read_text(encoding="utf-8")
assert str(tmp) not in durable
assert "FAKE_TOKEN=" not in durable
PY

FAKE_EVIDENCE="$TMP/fake-evidence"
python3 "$RUNNER" --scenario "$SCENARIO" --provider fake --runs 5 \
  --max-runs 5 --concurrency 2 --evidence-dir "$FAKE_EVIDENCE" >"$TMP/fake.json"
python3 - "$TMP/fake.json" "$FAKE_EVIDENCE" "$TMP" <<'PY'
import json
import sys
from pathlib import Path

report_path, evidence, tmp = map(Path, sys.argv[1:])
report = json.loads(report_path.read_text(encoding="utf-8"))
assert report["execution"]["max_observed_concurrency"] == 2
assert report["aggregate"]["candidate_variance"] > 0
raw = "\n".join(path.read_text(encoding="utf-8") for path in (evidence / "raw").glob("*.txt"))
assert "fake-secret-marker" in raw
assert str(tmp) in raw
durable = report_path.read_text(encoding="utf-8")
assert "fake-secret-marker" not in durable
assert str(tmp) not in durable
assert "[REDACTED_SECRET]" in durable
assert "[REDACTED_PATH]" in durable
PY

CLAUDE_EVIDENCE="$TMP/claude-evidence"
python3 "$RUNNER" --scenario "$SCENARIO" --provider claude --runs 1 \
  --max-runs 5 --concurrency 1 --max-cost-usd 1 --confirm-cost \
  --evidence-dir "$CLAUDE_EVIDENCE" >"$TMP/claude.json"
python3 - "$TMP/claude.json" "$CLAUDE_EVIDENCE" <<'PY'
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert report["provider"]["status"] == "not_live_tested"
assert report["execution"]["provider_calls"] == 0
assert not (Path(sys.argv[2]) / "raw").exists()
PY

echo "PASS: sandboxed reusable skill microtest"
