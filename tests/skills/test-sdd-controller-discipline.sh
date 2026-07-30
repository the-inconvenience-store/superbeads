#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SDD="$ROOT/skills/subagent-driven-development/SKILL.md"
SCHEDULING="$ROOT/skills/subagent-driven-development/references/scheduling.md"
CODEX="$ROOT/skills/subagent-driven-development/references/codex-mode.md"
PARALLEL="$ROOT/skills/dispatching-parallel-agents/SKILL.md"
MANIFEST="$ROOT/skills/subagent-driven-development/scripts/sdd-manifest.py"
FIXTURE="$ROOT/tests/fixtures/sdd-manifests/valid.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PYTHONPYCACHEPREFIX="$TMP/pycache"

for file in "$SDD" "$SCHEDULING" "$CODEX" "$PARALLEL"; do
  for text in "completion signal" "phase-overrun"; do
    grep -Fqi "$text" "$file" || {
      echo "FAIL: ${file#$ROOT/} missing $text" >&2
      exit 1
    }
  done
done
grep -Fqi "Do not use shell sleep" "$CODEX" || {
  echo "FAIL: Codex mode permits shell sleep polling" >&2
  exit 1
}
grep -Fqi "launch receipt" "$CODEX" || {
  echo "FAIL: Codex mode has no launch receipt" >&2
  exit 1
}

python3 - "$FIXTURE" "$TMP/manifest.json" "$TMP/receipt.json" "$TMP/events.jsonl" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text())
manifest["model_requested"] = "gpt-5.6-terra"
manifest["model_effective"] = "gpt-5.6-terra"
manifest["model_control"] = "explicit"
manifest["context_mode"] = "isolated"
manifest["capability_tier"] = "isolated"
Path(sys.argv[2]).write_text(json.dumps(manifest))
events = [
  {"type":"session_meta","payload":{
    "id":"codex-session-1","source":"exec","originator":"codex_exec"
  }},
  {"type":"response_item","payload":{
    "type":"message","role":"assistant","content":"Task complete."
  }}
]
events_text="".join(json.dumps(item)+"\n" for item in events)
Path(sys.argv[4]).write_text(events_text)
receipt = {
    "schema_version": 1,
    "task_id": manifest["task_id"],
    "contract_hash": manifest["contract_hash"],
    "worker_kind": "codex-cli",
    "transport": "codex_exec",
    "argv_model": "gpt-5.6-terra",
    "model_effective": "gpt-5.6-terra",
    "context_mode": "isolated",
    "session_id": "codex-session-1",
    "events_sha256": hashlib.sha256(events_text.encode()).hexdigest()
}
Path(sys.argv[3]).write_text(json.dumps(receipt))
PY

python3 "$MANIFEST" check-receipt \
  --manifest "$TMP/manifest.json" \
  --receipt "$TMP/receipt.json" \
  --events "$TMP/events.jsonl" \
  --expected-worker codex-cli \
  | grep -Fq "PASS worker launch receipt"

python3 - "$TMP/receipt.json" "$TMP/wrong-worker.json" <<'PY'
import json
import sys
from pathlib import Path
value = json.loads(Path(sys.argv[1]).read_text())
value["worker_kind"] = "claude-subagent"
Path(sys.argv[2]).write_text(json.dumps(value))
PY
if python3 "$MANIFEST" check-receipt \
  --manifest "$TMP/manifest.json" \
  --receipt "$TMP/wrong-worker.json" \
  --events "$TMP/events.jsonl" \
  --expected-worker codex-cli >"$TMP/wrong.out" 2>&1; then
  echo "FAIL: substituted worker passed the mode gate" >&2
  exit 1
fi
grep -Fq "worker_kind" "$TMP/wrong.out"

printf '%s\n' '{"type":"response_item","payload":{"type":"message","content":"changed"}}' \
  >>"$TMP/events.jsonl"
if python3 "$MANIFEST" check-receipt \
  --manifest "$TMP/manifest.json" --receipt "$TMP/receipt.json" \
  --events "$TMP/events.jsonl" --expected-worker codex-cli \
  >"$TMP/tampered.out" 2>&1; then
  echo "FAIL: changed Codex transport evidence passed the mode gate" >&2
  exit 1
fi
grep -Fq "events_sha256" "$TMP/tampered.out"

echo "PASS: SDD controller liveness and mode fidelity"
