#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
METRICS="$ROOT/scripts/workflow-metrics.py"
BASELINE="$ROOT/tests/fixtures/workflow-metrics/baseline.json"
PATHS="$ROOT/tests/fixtures/workflow-metrics/paths.json"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

python3 "$METRICS" snapshot --output "$TMP/snapshot.json"

python3 - "$TMP/snapshot.json" <<'PY'
import json
import sys
from pathlib import Path

snapshot = json.loads(Path(sys.argv[1]).read_text())
expected_keys = {
    "schema_version",
    "generated_from",
    "skills_all_words",
    "loaded_path_words",
    "matched_legacy_words",
    "description_bytes",
    "rendered_bytes",
}
assert set(snapshot) == expected_keys, set(snapshot)
assert snapshot["schema_version"] == 1
assert snapshot["skills_all_words"] == 48089
assert snapshot["loaded_path_words"] == {
    "product_discovery": 20598,
    "accepted_contract": 20598,
    "internal_bypass": 14648,
}
assert snapshot["matched_legacy_words"] == 20598
assert snapshot["description_bytes"] == 4067
assert set(snapshot["rendered_bytes"]) == {"startup", "resume", "clear", "compact"}
assert all(value == 4563 for value in snapshot["rendered_bytes"].values())
PY

cmp "$TMP/snapshot.json" "$BASELINE"
python3 "$METRICS" compare --baseline "$BASELINE" --candidate "$TMP/snapshot.json"

python3 - "$BASELINE" "$TMP/over.json" "$TMP/lower.json" <<'PY'
import copy
import json
import sys
from pathlib import Path

baseline = json.loads(Path(sys.argv[1]).read_text())
over = copy.deepcopy(baseline)
over["rendered_bytes"]["startup"] += 1
Path(sys.argv[2]).write_text(json.dumps(over, indent=2) + "\n")
lower = copy.deepcopy(baseline)
lower["rendered_bytes"]["startup"] -= 1
Path(sys.argv[3]).write_text(json.dumps(lower, indent=2) + "\n")
PY

python3 "$METRICS" compare --baseline "$BASELINE" --candidate "$TMP/lower.json"
if python3 "$METRICS" compare --baseline "$BASELINE" --candidate "$TMP/over.json" >"$TMP/over.out" 2>&1; then
  echo "FAIL: over-budget candidate passed"; exit 1
fi
grep -q 'rendered_bytes.startup' "$TMP/over.out" || {
  echo "FAIL: over-budget error did not name rendered_bytes.startup"; exit 1;
}

python3 - "$PATHS" "$TMP/unknown.json" "$TMP/duplicate.json" "$TMP/escape.json" <<'PY'
import copy
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text())
for target, value in zip(sys.argv[2:], ["skills/missing/SKILL.md", "skills/using-superpowers/../using-superpowers/SKILL.md", "../AGENTS.md"]):
    fixture = copy.deepcopy(source)
    fixture["internal_bypass"].append(value)
    Path(target).write_text(json.dumps(fixture, indent=2) + "\n")
PY

for case in unknown duplicate escape; do
  if python3 "$METRICS" snapshot --paths "$TMP/$case.json" --output "$TMP/$case-output.json" >"$TMP/$case.out" 2>&1; then
    echo "FAIL: $case manifest path passed"; exit 1
  fi
done
grep -q 'skills/missing/SKILL.md' "$TMP/unknown.out" || { echo "FAIL: unknown path error was imprecise"; exit 1; }
grep -q 'duplicate.*internal_bypass' "$TMP/duplicate.out" || { echo "FAIL: duplicate path error was imprecise"; exit 1; }
grep -q '../AGENTS.md' "$TMP/escape.out" || { echo "FAIL: escaping path error was imprecise"; exit 1; }

mkdir -p "$TMP/root/skills/bad"
printf '%s\n' 'name: bad' 'description: missing delimiters' > "$TMP/root/skills/bad/SKILL.md"
cat > "$TMP/malformed-paths.json" <<'JSON'
{
  "schema_version": 1,
  "product_discovery": ["skills/bad/SKILL.md"],
  "accepted_contract": ["skills/bad/SKILL.md"],
  "internal_bypass": ["skills/bad/SKILL.md"],
  "matched_legacy": ["skills/bad/SKILL.md"]
}
JSON
if python3 "$METRICS" snapshot --root "$TMP/root" --paths "$TMP/malformed-paths.json" --output "$TMP/malformed.json" >"$TMP/malformed.out" 2>&1; then
  echo "FAIL: malformed frontmatter passed"; exit 1
fi
grep -q 'skills/bad/SKILL.md.*frontmatter' "$TMP/malformed.out" || {
  echo "FAIL: malformed frontmatter error was imprecise"; exit 1;
}

echo "PASS: workflow metrics"
