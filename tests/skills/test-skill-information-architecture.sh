#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/skills/writing-skills/SKILL.md"
REFERENCE="$ROOT/skills/writing-skills/information-architecture.md"
LINTER="$ROOT/scripts/check-skill-frontmatter.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for heading in "Trigger / Non-trigger" Inputs Steps Completion Routing "Conditional References"; do
  grep -Fq "## $heading" "$SKILL" || { echo "FAIL: writing-skills spine missing $heading" >&2; exit 1; }
done

grep -Fq 'NO SKILL WITHOUT A FAILING TEST FIRST' "$SKILL"
grep -Fq 'information-architecture.md' "$SKILL"
test "$(wc -w < "$SKILL")" -le 1200

for term in Predictability "Information hierarchy" "Context pointer" "Single source of truth" No-op Sediment "Positive target" "Completion criterion"; do
  grep -Fqi "$term" "$REFERENCE" || { echo "FAIL: information architecture missing $term" >&2; exit 1; }
done
grep -Fq 'https://raw.githubusercontent.com/mattpocock/skills/refs/heads/main/skills/productivity/writing-great-skills/SKILL.md' "$REFERENCE"
grep -Fq 'https://raw.githubusercontent.com/mattpocock/skills/refs/heads/main/skills/productivity/writing-great-skills/GLOSSARY.md' "$REFERENCE"

python3 "$LINTER"

mkdir -p "$TMP/bad-trigger/skills/example" "$TMP/process-summary/skills/example" "$TMP/valid/skills/example"
printf '%s\n' '---' 'name: example' 'description: Reference for doing examples' '---' >"$TMP/bad-trigger/skills/example/SKILL.md"
printf '%s\n' '---' 'name: example' 'description: Use when examples are requested; this skill dispatches workers' '---' >"$TMP/process-summary/skills/example/SKILL.md"
printf '%s\n' '---' 'name: example' 'description: Use when an example is requested.' '---' >"$TMP/valid/skills/example/SKILL.md"

if python3 "$LINTER" --root "$TMP/bad-trigger" >"$TMP/bad-trigger.out" 2>&1; then
  echo "FAIL: non-trigger description passed" >&2; exit 1
fi
grep -Fq 'must start with' "$TMP/bad-trigger.out"

if python3 "$LINTER" --root "$TMP/process-summary" >"$TMP/process-summary.out" 2>&1; then
  echo "FAIL: process-summary description passed" >&2; exit 1
fi
grep -Fq 'summarizes process' "$TMP/process-summary.out"

python3 "$LINTER" --root "$TMP/valid"
if python3 "$LINTER" --root "$TMP/valid" --max-description-bytes 20 >"$TMP/budget.out" 2>&1; then
  echo "FAIL: catalogue budget mutation passed" >&2; exit 1
fi
grep -Fq 'description catalogue' "$TMP/budget.out"

echo "PASS: skill information architecture"
