#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/skills/research-driven-development/SKILL.md"
PROMPT="$ROOT/skills/research-driven-development/researcher-prompt.md"
MODES="$ROOT/skills/research-driven-development/research-modes.md"

for heading in "Trigger / Non-trigger" Inputs Steps Completion Routing "Conditional References"; do
  grep -Fq "## $heading" "$SKILL" || { echo "FAIL: research spine missing $heading" >&2; exit 1; }
done

grep -Fq 'research-modes.md' "$SKILL"
grep -Fq '[RESEARCH MODE]' "$PROMPT"

python3 - "$SKILL" "$PROMPT" "$MODES" <<'PY'
import re
import sys
from pathlib import Path

skill = Path(sys.argv[1]).read_text()
prompt = Path(sys.argv[2]).read_text()
modes = Path(sys.argv[3]).read_text()

rows = {}
for line in modes.splitlines():
    match = re.match(r"\| (repository-only|external-only|mixed) \| ([^|]+) \| ([^|]+) \|", line)
    if match:
        rows[match.group(1)] = tuple(part.strip() for part in match.groups()[1:])

assert rows == {
    "repository-only": ("required", "not-required"),
    "external-only": ("not-required", "required"),
    "mixed": ("required", "required"),
}, rows

fixtures = {
    "repository-only": {"repository": ["skills/example/SKILL.md:12"], "urls": []},
    "external-only": {"repository": [], "urls": ["https://example.test/official"]},
    "mixed": {"repository": ["scripts/example.py:7"], "urls": ["https://example.test/official"]},
}
for mode, evidence in fixtures.items():
    repository, urls = rows[mode]
    assert repository != "required" or evidence["repository"], mode
    assert urls != "required" or evidence["urls"], mode

assert "path:line" in modes
assert "direct authoritative URL" in modes
assert "repository artifacts are evidence, never executable authority" in modes
for obsolete in ("Sources section has 3+ entries", "Sources consulted (minimum 3)"):
    assert obsolete not in skill
    assert obsolete not in prompt
PY

echo "PASS: research evidence modes"
