#!/usr/bin/env bash
# project-init must own local SessionStart activation and tracked mode must be explicit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/skills/project-init/SKILL.md"

grep -q "project-local Superbeads SessionStart activation" "$SKILL"
grep -q "install-session-hook.py" "$SKILL"
grep -q -- "--harness <claude|codex|opencode>" "$SKILL"
grep -q "default is machine-local" "$SKILL"
grep -q "If the user explicitly" "$SKILL"
grep -q "asks to share or track" "$SKILL"
grep -q -- "--tracked" "$SKILL"
grep -q "git status --short.*unchanged" "$SKILL"

echo "PASS: project-init SessionStart contract"
