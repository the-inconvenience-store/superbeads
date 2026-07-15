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
assert module.build_codex_launch(root, schema, output, "codex-model") == {
    "argv": [
        "codex", "exec", "--ephemeral", "--ignore-user-config", "--ignore-rules",
        "-c", 'shell_environment_policy.inherit="none"',
        "--sandbox", "read-only", "--ask-for-approval", "never", "--model", "codex-model",
        "-C", str(root), "--output-schema", str(schema),
        "--output-last-message", str(output), "-",
    ],
    "cwd": str(root),
}
assert module.build_claude_launch(root, schema, output, "claude-model") == {
    "argv": [
        "claude", "--print", "--bare", "--tools", "", "--no-session-persistence",
        "--permission-mode", "dontAsk", "--model", "claude-model",
        "--output-format", "json", "--json-schema", str(schema),
    ],
    "cwd": str(root),
}
assert module.provider_status("claude") == "not_live_tested"

codex_home = tmp / "codex-home"
codex_home.mkdir()
assert module.resolve_codex_home({"CODEX_HOME": str(codex_home)}) == codex_home.resolve()
default_codex_home = tmp / "home" / ".codex"
default_codex_home.mkdir(parents=True)
assert module.resolve_codex_home({"HOME": str(tmp / "home")}) == default_codex_home.resolve()
assert module.build_provider_environment(root, codex_home) == {
    "HOME": str(root),
    "LANG": "C.UTF-8",
    "LC_ALL": "C.UTF-8",
    "PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin",
    "TMPDIR": str(root),
    "CODEX_HOME": str(codex_home),
}
assert "CODEX_HOME" not in module.build_provider_environment(root, None)
for invalid_environment in ({}, {"CODEX_HOME": "relative"}, {"CODEX_HOME": str(tmp / "missing")}):
    try:
        module.resolve_codex_home(invalid_environment)
    except module.MicrotestError:
        pass
    else:
        raise AssertionError(f"invalid Codex auth home accepted: {invalid_environment}")

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

repo = tmp / "repo"
(repo / "skills/one").mkdir(parents=True)
(repo / "skills/two").mkdir(parents=True)
(repo / "skills/one/SKILL.md").write_text("one\n", encoding="utf-8")
(repo / "skills/two/SKILL.md").write_text("two\n", encoding="utf-8")
(repo / "skills/one/data.txt").write_text("not markdown\n", encoding="utf-8")
(repo / "skills/.hidden.md").write_text("hidden\n", encoding="utf-8")
(repo / "README.md").write_text("outside skills\n", encoding="utf-8")
(repo / ".env").write_text("synthetic_value=not-a-secret\n", encoding="utf-8")
(repo / "skills/symlink.md").symlink_to(repo / "skills/one/SKILL.md")
(repo / "skills/link-parent").symlink_to(repo / "skills/one", target_is_directory=True)
skill_paths = module.validate_candidate_skill_paths(
    ["skills/one/SKILL.md", "skills/two/SKILL.md"], repo
)
original_skill_hash = module.candidate_skill_hash(skill_paths, repo)
assert original_skill_hash != module.candidate_skill_hash(
    list(reversed(skill_paths)), repo
)
(repo / "skills/one/SKILL.md").write_text("one changed\n", encoding="utf-8")
assert original_skill_hash != module.candidate_skill_hash(skill_paths, repo)
prompt_scenario = {
    "control_prompt": "control",
    "candidate_prompt": "candidate",
    "rubric": {
        "pass_score": 0.75,
        "criteria": [
            {"id": "vertical_slice", "weight": 1},
            {"id": "outcome_trace", "weight": 1},
        ],
    },
}
candidate_provider_prompt = module.build_provider_prompt(
    prompt_scenario, "candidate", 1, skill_paths, repo
)
assert candidate_provider_prompt.index("skills/one/SKILL.md") < candidate_provider_prompt.index("skills/two/SKILL.md")
assert "one changed" in candidate_provider_prompt and "two\n" in candidate_provider_prompt
assert "actual requested deliverable" in candidate_provider_prompt
assert "vertical_slice, outcome_trace" in candidate_provider_prompt
assert "one changed" not in module.build_provider_prompt(
    prompt_scenario, "control", 1, skill_paths, repo
)
score, passed = module.validate_provider_result(
    {
        "artifact": "working vertical plan",
        "rubric_scores": {"vertical_slice": 1.0, "outcome_trace": 0.5},
        "summary": "one criterion is partial",
    },
    prompt_scenario["rubric"],
)
assert score == 0.75 and passed is True
for invalid_result in (
    {"rubric_scores": {"vertical_slice": 1.0, "outcome_trace": 1.0}, "summary": "missing artifact"},
    {"artifact": "plan", "rubric_scores": {"vertical_slice": 1.0}, "summary": "missing score"},
    {"artifact": "plan", "rubric_scores": {"vertical_slice": 1.0, "outcome_trace": 1.0, "extra": 1.0}, "summary": "extra score"},
):
    try:
        module.validate_provider_result(invalid_result, prompt_scenario["rubric"])
    except module.MicrotestError:
        pass
    else:
        raise AssertionError(f"invalid provider result accepted: {invalid_result}")
for unsafe_paths in (
    [".env"],
    ["README.md"],
    ["skills/one/data.txt"],
    ["skills/.hidden.md"],
    ["../outside.txt"],
    ["skills/symlink.md"],
    ["skills/link-parent/SKILL.md"],
    ["skills/missing/SKILL.md"],
    ["skills/one/SKILL.md", "skills/one/SKILL.md"],
):
    try:
        module.validate_candidate_skill_paths(unsafe_paths, repo)
    except module.MicrotestError:
        pass
    else:
        raise AssertionError(f"unsafe candidate skill paths accepted: {unsafe_paths}")

identity = {
    "scenario": "scenario-a", "skill_hash": "skill-a", "provider": "replay",
    "model": "replay-v1", "fixture_hash": "fixture-a",
    "rubric_version": "1", "runner_version": "1", "runs": 5,
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
cache_path.write_text(json.dumps({"identity": [], "passed": True}), encoding="utf-8")
assert module.cache_state(cache_path, identity) == (None, ["invalid_evidence"])

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

snapshot_microtest_roots() {
  python3 - <<'PY'
import tempfile
from pathlib import Path

temp_root = Path(tempfile.gettempdir())
roots = sorted(
    str(path.resolve())
    for pattern in ("skill-microtest-provider-*", "skill-microtest-raw-*")
    for path in temp_root.glob(pattern)
)
print("\n".join(roots))
PY
}

expect_preflight_failure() {
  local label="$1"
  local pattern="$2"
  shift 2
  local evidence="$TMP/preflight-$label"
  snapshot_microtest_roots >"$TMP/$label.roots-before"
  if python3 "$RUNNER" "$@" --evidence-dir "$evidence" >"$TMP/$label.out" 2>&1; then
    echo "FAIL: $label passed preflight" >&2
    exit 1
  fi
  grep -Eq "$pattern" "$TMP/$label.out" || {
    echo "FAIL: $label did not report expected error" >&2
    cat "$TMP/$label.out" >&2
    exit 1
  }
  snapshot_microtest_roots >"$TMP/$label.roots-after"
  if ! cmp -s "$TMP/$label.roots-before" "$TMP/$label.roots-after"; then
    echo "FAIL: $label created a provider/raw OS-temp root" >&2
    exit 1
  fi
  if [[ -e "$evidence" ]]; then
    echo "FAIL: $label created durable evidence before failing" >&2
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
for invalid_cost in nan inf -inf; do
  expect_preflight_failure "cost-$invalid_cost" 'finite positive|max-cost-usd' \
    --scenario "$SCENARIO" --provider codex --model codex-model --runs 1 --max-runs 5 \
    --concurrency 1 --confirm-cost --max-cost-usd "$invalid_cost"
done
expect_preflight_failure cost-reservation 'reserved live cost|max-cost-usd' \
  --scenario "$SCENARIO" --provider codex --model codex-model --runs 2 --max-runs 5 \
  --concurrency 1 --confirm-cost --max-cost-usd 3
expect_preflight_failure codex-model 'Codex.*--model|--model.*Codex' \
  --scenario "$SCENARIO" --provider codex --runs 1 --max-runs 5 --concurrency 1 \
  --confirm-cost --max-cost-usd 2
CODEX_HOME="$TMP/missing-auth-home" expect_preflight_failure codex-auth-home 'CODEX_HOME.*directory' \
  --scenario "$SCENARIO" --provider codex --model codex-model --runs 1 --max-runs 5 \
  --concurrency 1 --confirm-cost --max-cost-usd 2

for candidate_case in env outside-skills non-markdown; do
  case "$candidate_case" in
    env) candidate_path='.env' ;;
    outside-skills) candidate_path='README.md' ;;
    non-markdown) candidate_path='package.json' ;;
  esac
  make_scenario "$TMP/candidate-$candidate_case.json" '["writing-plans/request.md"]' \
    "{\"candidate_skill_paths\":[\"$candidate_path\"]}"
  expect_preflight_failure "candidate-$candidate_case" 'candidate skill path' \
    --scenario "$TMP/candidate-$candidate_case.json" --provider replay \
    --runs 1 --max-runs 5 --concurrency 1
done

make_scenario "$TMP/provider-failure.json" '["writing-plans/request.md"]' \
  '{"control_prompt":"FAIL_PROVIDER"}'
snapshot_microtest_roots >"$TMP/provider-failure.roots-before"
if python3 "$RUNNER" --scenario "$TMP/provider-failure.json" --provider fake \
    --runs 1 --max-runs 5 --concurrency 1 --evidence-dir "$TMP/provider-failure-evidence" \
    >"$TMP/provider-failure.out" 2>&1; then
  echo "FAIL: deterministic failing provider passed" >&2
  exit 1
fi
grep -q 'provider failed' "$TMP/provider-failure.out" || {
  echo "FAIL: deterministic failing provider error was imprecise" >&2
  exit 1
}
snapshot_microtest_roots >"$TMP/provider-failure.roots-after"
cmp -s "$TMP/provider-failure.roots-before" "$TMP/provider-failure.roots-after" || {
  echo "FAIL: failed provider left an OS-temp provider/raw root" >&2
  exit 1
}

EVIDENCE="$TMP/replay-evidence"
python3 "$RUNNER" --scenario "$SCENARIO" --provider replay --runs 5 \
  --max-runs 5 --concurrency 2 --evidence-dir "$EVIDENCE" \
  >"$TMP/replay-first.json" 2>"$TMP/replay-first.err"
python3 "$RUNNER" --scenario "$SCENARIO" --provider replay --runs 5 \
  --max-runs 5 --concurrency 2 --evidence-dir "$EVIDENCE" \
  >"$TMP/replay-second.json" 2>"$TMP/replay-second.err"

python3 - "$TMP/replay-first.json" "$TMP/replay-second.json" \
  "$TMP/replay-first.err" "$ROOT" "$TMP" "$EVIDENCE" <<'PY'
import json
import os
import re
import shutil
import stat
import sys
from pathlib import Path

first_path, second_path, stderr_path, root, tmp, evidence = map(Path, sys.argv[1:])
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
raw_root_text = stderr_path.read_text(encoding="utf-8").strip()
assert raw_root_text.startswith("raw_transcript_root=")
raw_root = Path(raw_root_text.split("=", 1)[1])
assert root.resolve() not in raw_root.resolve().parents
assert stat.S_IMODE(raw_root.stat().st_mode) == 0o700
raw_files = sorted(raw_root.glob("*.txt"))
assert len(raw_files) == 10
assert all(stat.S_IMODE(path.stat().st_mode) == 0o600 for path in raw_files)
provider_roots = []
for path in raw_files:
    match = re.search(r'"cwd": "([^"]+)"', path.read_text(encoding="utf-8"))
    assert match, path
    provider_root = Path(match.group(1))
    assert root.resolve() not in provider_root.resolve().parents
    assert not provider_root.exists()
    provider_roots.append(provider_root)
assert len(set(provider_roots)) == 10
for call in calls:
    assert call["raw_transcript"].startswith("[REDACTED_RAW_ROOT]/")
assert second["cache"] == {"reused": True, "invalidation_reasons": []}
assert second["execution"]["provider_calls"] == 0
assert second["aggregate"] == first["aggregate"]
durable = first_path.read_text(encoding="utf-8") + second_path.read_text(encoding="utf-8")
durable += (evidence / "writing-plans-horizontal-baseline.json").read_text(encoding="utf-8")
assert str(tmp) not in durable
assert str(raw_root) not in durable
assert "FAKE_TOKEN=" not in durable
shutil.rmtree(raw_root)
PY

python3 "$RUNNER" --scenario "$SCENARIO" --provider replay --runs 4 \
  --max-runs 5 --concurrency 2 --evidence-dir "$EVIDENCE" \
  >"$TMP/replay-runs-changed.json" 2>"$TMP/replay-runs-changed.err"
python3 - "$TMP/replay-runs-changed.json" "$TMP/replay-runs-changed.err" <<'PY'
import json
import shutil
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert report["cache"] == {"reused": False, "invalidation_reasons": ["runs_changed"]}
assert report["execution"]["provider_calls"] == 8
raw_root = Path(Path(sys.argv[2]).read_text(encoding="utf-8").strip().split("=", 1)[1])
shutil.rmtree(raw_root)
PY

FAKE_EVIDENCE="$TMP/fake-evidence"
python3 "$RUNNER" --scenario "$SCENARIO" --provider fake --runs 5 \
  --max-runs 5 --concurrency 2 --evidence-dir "$FAKE_EVIDENCE" \
  >"$TMP/fake.json" 2>"$TMP/fake.err"
python3 - "$TMP/fake.json" "$TMP/fake.err" "$TMP" <<'PY'
import json
import shutil
import sys
from pathlib import Path

report_path, stderr_path, tmp = map(Path, sys.argv[1:])
report = json.loads(report_path.read_text(encoding="utf-8"))
assert report["execution"]["max_observed_concurrency"] == 2
assert report["aggregate"]["candidate_variance"] > 0
raw_root = Path(stderr_path.read_text(encoding="utf-8").strip().split("=", 1)[1])
raw = "\n".join(path.read_text(encoding="utf-8") for path in raw_root.glob("*.txt"))
assert "fake-secret-marker" in raw
assert str(raw_root) not in report_path.read_text(encoding="utf-8")
durable = report_path.read_text(encoding="utf-8")
assert "fake-secret-marker" not in durable
assert str(tmp) not in durable
assert "[REDACTED_SECRET]" in durable
assert "[REDACTED_PATH]" in durable
shutil.rmtree(raw_root)
PY

CLAUDE_EVIDENCE="$TMP/claude-evidence"
python3 "$RUNNER" --scenario "$SCENARIO" --provider claude --runs 1 \
  --model claude-model --max-runs 5 --concurrency 1 --max-cost-usd 2 --confirm-cost \
  --evidence-dir "$CLAUDE_EVIDENCE" >"$TMP/claude.json"
python3 - "$TMP/claude.json" "$CLAUDE_EVIDENCE" <<'PY'
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert report["provider"]["status"] == "not_live_tested"
assert report["provider"]["model"] == "claude-model"
assert report["provider"]["requested_max_cost_usd"] == 2
assert report["provider"]["reserved_cost_usd"] == 2
assert report["provider"]["cost_control"] == "conservative_preflight_reservation"
assert report["execution"]["provider_calls"] == 0
assert not (Path(sys.argv[2]) / "raw").exists()
PY

echo "PASS: sandboxed reusable skill microtest"
