#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

require_text() {
  local file="$1"
  local pattern="$2"
  if ! grep -Fq "$pattern" "$ROOT/$file"; then
    echo "FAIL: $file is missing required outcome-acceptance contract: $pattern" >&2
    exit 1
  fi
}

require_text "skills/brainstorming/SKILL.md" "## Product Outcome Contract"
require_text "skills/writing-plans/SKILL.md" "## Outcome Trace"
require_text "skills/subagent-driven-development/SKILL.md" "./outcome-reviewer-prompt.md"
require_text "skills/subagent-driven-development/SKILL.md" "only if user requested draft PR/branch disposition"
require_text "skills/verification-before-completion/SKILL.md" "NO REQUIRED VERIFICATION MAY BE SUBSTITUTED"
require_text "skills/finishing-a-development-branch/SKILL.md" "READY_FOR_CODE_REVIEW"
require_text "skills/finishing-a-development-branch/SKILL.md" "Open draft PR"

if [[ ! -f "$ROOT/skills/subagent-driven-development/outcome-reviewer-prompt.md" ]]; then
  echo "FAIL: subagent-driven-development is missing outcome-reviewer-prompt.md" >&2
  exit 1
fi

echo "PASS: outcome acceptance contract is present across workflow skills"
