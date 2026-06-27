#!/usr/bin/env bash
# Verify the agent-filed bead discipline convention is present where required.
set -euo pipefail
CANON="skills/verification-before-completion/SKILL.md"
REQUIRED=(
  "skills/verification-before-completion/SKILL.md"
  "skills/finishing-a-development-branch/SKILL.md"
  "skills/executing-plans/SKILL.md"
  "skills/subagent-driven-development/SKILL.md"
  "skills/requesting-code-review/code-reviewer.md"
  "skills/brainstorming/SKILL.md"
  "skills/writing-plans/SKILL.md"
)
fail=0
grep -q "^## Agent-Filed Bead Discipline" "$CANON" || { echo "MISSING canonical section in $CANON"; fail=1; }
for f in "${REQUIRED[@]}"; do
  grep -q "Agent-Filed Bead Discipline" "$f" || { echo "MISSING reference in $f"; fail=1; }
done
if [ "$fail" -eq 0 ]; then echo "agent-filed bead discipline: present at all ${#REQUIRED[@]} required sites"; fi
exit "$fail"
