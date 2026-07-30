#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICY="$ROOT/skills/using-superpowers/references/technical-writing-policy.md"
USING="$ROOT/skills/using-superpowers/SKILL.md"

test -f "$POLICY" || {
  echo "FAIL: missing shared technical writing policy" >&2
  exit 1
}

for text in \
  "ASD-STE100" "Issue 9" "durable technical artifacts" \
  "user workflow updates" "active voice" "one instruction per sentence" \
  "one term" "explicit actor" "American English" "20 words" "25 words" \
  "Do not claim full ASD-STE100 compliance" \
  "code" "identifier" "command" "quoted" "raw evidence" "machine-readable"; do
  grep -Fqi "$text" "$POLICY" || {
    echo "FAIL: technical writing policy missing $text" >&2
    exit 1
  }
done

grep -Fq "technical-writing-policy.md" "$USING" || {
  echo "FAIL: session policy does not reach every orchestrating agent" >&2
  exit 1
}

writers=(
  product-definition
  brainstorming
  writing-plans
  research-driven-development
  subagent-driven-development
  session-handoff
  write-documentation
  document-release
  getting-up-to-speed
  requesting-code-review
  receiving-code-review
  verification-before-completion
)
for skill in "${writers[@]}"; do
  file="$ROOT/skills/$skill/SKILL.md"
  test -f "$file" || { echo "FAIL: missing writer skill $skill" >&2; exit 1; }
  grep -Fq "technical-writing-policy.md" "$file" || {
    echo "FAIL: $skill does not point to the shared writing policy" >&2
    exit 1
  }
done

for prompt in \
  "$ROOT/skills/subagent-driven-development/implementer-prompt.md" \
  "$ROOT/skills/subagent-driven-development/task-reviewer-prompt.md" \
  "$ROOT/skills/subagent-driven-development/outcome-reviewer-prompt.md" \
  "$ROOT/skills/research-driven-development/researcher-prompt.md"; do
  grep -Fq "technical-writing-policy.md" "$prompt" || {
    echo "FAIL: ${prompt#$ROOT/} does not bind worker prose" >&2
    exit 1
  }
done

echo "PASS: shared simplified technical writing policy"
