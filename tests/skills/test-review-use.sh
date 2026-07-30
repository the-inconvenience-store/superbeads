#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/.agents/skills/review-use/SKILL.md"
COLLECT="$ROOT/.agents/skills/review-use/scripts/collect.py"
ANALYZE="$ROOT/.agents/skills/review-use/scripts/analyze.py"
REGISTRY_TOOL="$ROOT/.agents/skills/review-use/scripts/registry.py"
REGISTRY="$ROOT/.agents/skills/review-use/references/anti-patterns.json"
FIXTURES="$ROOT/tests/fixtures/review-use"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PYTHONPYCACHEPREFIX="$TMP/pycache"

for file in "$SKILL" "$COLLECT" "$ANALYZE" "$REGISTRY_TOOL" "$REGISTRY"; do
  test -f "$file" || { echo "FAIL: missing ${file#$ROOT/}" >&2; exit 1; }
done

for text in "Use when" "Claude" "Codex" "main agent" "subagent" "docs/reviews/" \
  "untrusted data" "anti-patterns.json" "three separate reviews" "21 days" \
  "one failure per 100 reviewed sessions"; do
  grep -Fqi "$text" "$SKILL" || { echo "FAIL: review-use skill missing $text" >&2; exit 1; }
done

python3 "$REGISTRY_TOOL" validate --registry "$REGISTRY"
python3 - "$REGISTRY" <<'PY'
import json, re, sys
from pathlib import Path
registry=json.loads(Path(sys.argv[1]).read_text())
pattern=next(item for item in registry["patterns"] if item["id"]=="RU-AP-007")
expression=re.compile(pattern["detector"]["config"]["pattern"])
assert expression.search("open docs/specs/feature.md")
assert expression.search("git status; open docs/plans/feature.md")
assert not expression.search("echo 'please open docs/specs/feature.md'")
assert not expression.search("rg open docs/specs/feature.md")
PY
python3 "$COLLECT" discover \
  --claude-root "$FIXTURES/claude" --codex-root "$FIXTURES/codex" \
  --output "$TMP/manifest.json"
python3 - "$TMP/manifest.json" <<'PY'
import json, sys
from pathlib import Path
data=json.loads(Path(sys.argv[1]).read_text())
assert len(data["files"]) == 4, data
assert {item["platform"] for item in data["files"]} == {"claude","codex"}
PY

python3 "$COLLECT" normalize --manifest "$TMP/manifest.json" --output "$TMP/events.jsonl"
python3 - "$TMP/events.jsonl" <<'PY'
import json, sys
from pathlib import Path
events=[json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
sessions={(event["platform"],event["session_id"],event["agent_role"]) for event in events}
assert ("claude","claude-main","main") in sessions
assert ("claude","claude-main","subagent") in sessions
assert ("codex","codex-main","main") in sessions
assert ("codex","codex-child","subagent") in sessions
assert sum(event["content_available"] is False for event in events) == 1
PY

python3 - "$ANALYZE" <<'PY'
import importlib.util
import sys
from pathlib import Path

spec=importlib.util.spec_from_file_location("review_analyze", Path(sys.argv[1]))
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class CountingList(list):
    iterations=0
    def __iter__(self):
        type(self).iterations += 1
        return super().__iter__()

events=CountingList([
  {
    "platform":"claude","source_path":"session.jsonl","session_id":"controller",
    "agent_id":None,"agent_role":"main","tool_name":"Bash",
    "command":"sleep 1; ps -ef; tail -n 20 worker.out","content_available":True,
  }
  for _ in range(11)
])
events.append({
  "platform":"codex","source_path":"worker.jsonl","session_id":"leaf",
  "agent_id":"leaf","agent_role":"subagent","tool_name":"wait_agent",
  "command":None,"content_available":True,
})
metrics=module.corpus_metrics(events)
assert CountingList.iterations <= 2, CountingList.iterations
assert metrics["poll_events"] == 11, metrics
assert metrics["poll_sessions"] == 1, metrics
assert metrics["completion_wait_events"] == 1, metrics
assert metrics["requested_sleep_seconds"] == 11.0, metrics
PY

cat >"$TMP/prior.json" <<'JSON'
{
  "schema_version": 1,
  "review_id": "review-prior",
  "date": "2026-07-16",
  "status": "complete",
  "failures": [
    {
      "pattern_id": "RU-AP-006",
      "count": 2,
      "rate_per_100_sessions": 50.0
    }
  ]
}
JSON
python3 "$ANALYZE" scan \
  --events "$TMP/events.jsonl" --registry "$REGISTRY" \
  --manual "$FIXTURES/manual.json" --review-id review-1 --date 2026-07-23 \
  --scope fixture --prior "$TMP/prior.json" --output "$TMP/review.json"
python3 - "$TMP/review.json" <<'PY'
import json, sys
from pathlib import Path
data=json.loads(Path(sys.argv[1]).read_text())
by_id={row["pattern_id"]:row for row in data["failures"]}
assert by_id["RU-AP-001"]["count"] == 1
assert by_id["RU-AP-006"]["count"] == 1
assert by_id["RU-AP-006"]["previous_rate"] == 50.0
assert by_id["RU-AP-006"]["trend"] == "falling"
assert data["corpus"]["sessions"] == 4
assert "SECRET_SHOULD_NOT_LEAK" not in Path(sys.argv[1]).read_text()
assert "SECRET_MANUAL_SHOULD_NOT_LEAK" not in Path(sys.argv[1]).read_text()
for instance in data["instances"]:
    assert len(instance["evidence_hash"]) == 64
    assert "raw_text" not in instance
PY

mkdir -p "$TMP/docs/reviews"
python3 "$ANALYZE" render --data "$TMP/review.json" \
  --output "$TMP/docs/reviews/2026-07-23-fixture-superbeads-usage-review.md" \
  --verdict "Fixture review completed"
grep -Fq "## Failure summary" "$TMP/docs/reviews/2026-07-23-fixture-superbeads-usage-review.md"
grep -Fq "Pattern ID | Title | Status | Count | Per 100 sessions | Previous rate | Trend | Confidence" \
  "$TMP/docs/reviews/2026-07-23-fixture-superbeads-usage-review.md"
grep -Fq "## Failure instances" "$TMP/docs/reviews/2026-07-23-fixture-superbeads-usage-review.md"
grep -Fq "Requested sleep can overlap external work" \
  "$TMP/docs/reviews/2026-07-23-fixture-superbeads-usage-review.md"
grep -Fq "| RU-AP-006 | Episodic memory capture | active | 1 | 25.0 | 50.0 | falling | high |" \
  "$TMP/docs/reviews/2026-07-23-fixture-superbeads-usage-review.md"
if python3 "$ANALYZE" render --data "$TMP/review.json" \
  --output "$TMP/docs/reviews/2026-07-23-fixture-superbeads-usage-review.md" \
  --verdict "Should not overwrite" >"$TMP/overwrite.out" 2>&1; then
  echo "FAIL: render overwrote an existing review without --replace" >&2; exit 1
fi

cp "$REGISTRY" "$TMP/registry.json"
python3 "$REGISTRY_TOOL" add --registry "$TMP/registry.json" \
  --id RU-AP-999 --title "New confirmed pattern" --category test \
  --description "A confirmed, independently falsifiable test pattern." \
  --kind manual --config-json '{}' --review-id review-1 --date 2026-07-01
if python3 "$REGISTRY_TOOL" add --registry "$TMP/registry.json" \
  --id RU-AP-999 --title duplicate --category test --description duplicate \
  --kind manual --config-json '{}' --review-id review-1 --date 2026-07-01 \
  >"$TMP/duplicate.out" 2>&1; then
  echo "FAIL: duplicate registry ID passed" >&2; exit 1
fi

python3 - "$TMP" <<'PY'
import json, sys
from pathlib import Path
root=Path(sys.argv[1])
def review(review_id,date,count,rate):
    return {
      "schema_version":1,"review_id":review_id,"date":date,"status":"complete",
      "failures":[{"pattern_id":"RU-AP-999","count":count,"rate_per_100_sessions":rate}]
    }
for i,(date,count,rate) in enumerate([
    ("2026-07-01",0,0.0),("2026-07-15",1,0.5),("2026-07-29",0,0.0)
],1):
    root.joinpath(f"history-{i}.json").write_text(json.dumps(review(f"history-{i}",date,count,rate)))
for i,date in enumerate(["2026-07-01","2026-07-08","2026-07-15"],1):
    root.joinpath(f"close-history-{i}.json").write_text(
        json.dumps(review(f"close-history-{i}",date,0,0.0))
    )
bad=review("history-bad","2026-08-05",2,2.0)
root.joinpath("history-bad.json").write_text(json.dumps(bad))
PY
if python3 "$REGISTRY_TOOL" retire --registry "$TMP/registry.json" --id RU-AP-999 \
  --history "$TMP/history-1.json" --history "$TMP/history-2.json" \
  >"$TMP/short-history.out" 2>&1; then
  echo "FAIL: retirement passed with fewer than three reviews" >&2; exit 1
fi
if python3 "$REGISTRY_TOOL" retire --registry "$TMP/registry.json" --id RU-AP-999 \
  --history "$TMP/history-1.json" --history "$TMP/history-2.json" \
  --history "$TMP/history-bad.json" >"$TMP/not-near-zero.out" 2>&1; then
  echo "FAIL: retirement passed above near-zero" >&2; exit 1
fi
if python3 "$REGISTRY_TOOL" retire --registry "$TMP/registry.json" --id RU-AP-999 \
  --history "$TMP/close-history-1.json" --history "$TMP/close-history-2.json" \
  --history "$TMP/close-history-3.json" >"$TMP/short-span.out" 2>&1; then
  echo "FAIL: retirement passed with less than a 21-day span" >&2; exit 1
fi
python3 "$REGISTRY_TOOL" retire --registry "$TMP/registry.json" --id RU-AP-999 \
  --history "$TMP/history-1.json" --history "$TMP/history-2.json" \
  --history "$TMP/history-3.json"
python3 - "$TMP/registry.json" <<'PY'
import json, sys
from pathlib import Path
registry=json.loads(Path(sys.argv[1]).read_text())
pattern=next(item for item in registry["patterns"] if item["id"]=="RU-AP-999")
assert pattern["status"] == "retired"
assert pattern["retired"]["qualifying_reviews"] == ["history-1","history-2","history-3"]
PY
python3 "$REGISTRY_TOOL" reactivate --registry "$TMP/registry.json" --id RU-AP-999
python3 - "$TMP/registry.json" <<'PY'
import json, sys
from pathlib import Path
registry=json.loads(Path(sys.argv[1]).read_text())
pattern=next(item for item in registry["patterns"] if item["id"]=="RU-AP-999")
assert pattern["status"] == "active"
assert pattern["retired"] is None
PY

echo "PASS: review-use skill contract"
