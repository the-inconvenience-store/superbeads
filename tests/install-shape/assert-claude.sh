#!/usr/bin/env bash
# assert-claude.sh — Tier A: full artifact + uninstall round-trip for Claude Code.
set -uo pipefail
# shellcheck source=tests/install-shape/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

shape_sandbox_setup claude
trap 'shape_sandbox_teardown' EXIT
mkdir -p "$SANDBOX/.claude"
printf '%s\n' \
  '{"hooks":{"SessionStart":[{"hooks":[' \
  '{"type":"command","command":"bash /tmp/superbeads-session-start.sh"},' \
  '{"type":"command","command":"bash /tmp/foreign-session-start.sh"}' \
  ']}]}}' > "$SANDBOX/.claude/settings.json"
shape_install

assert_all_skills "$SANDBOX/skills"
assert_file "$SANDBOX/skills/project-init/assets/session-start"
assert_no_file "$SANDBOX/.claude/hooks/superbeads-session-start.sh"
assert_no_file "$SANDBOX/.claude/hooks/superbeads"
assert_file "$SANDBOX/.claude/settings.json"
assert_json "$SANDBOX/.claude/settings.json" "'superbeads' not in json.dumps(d)"
assert_json "$SANDBOX/.claude/settings.json" "'foreign-session-start' in json.dumps(d)"
assert_no_file "$SANDBOX/.claude/hooks/superbeads-reminder.sh"
# Default install must NOT place the yegge agent (opt-in via --with-yegge, bead 3krn)
assert_no_file "$SANDBOX/.claude/agents/yegge.md"
assert_file "$SANDBOX/skills/.superbeads-version"
grep -q ":local$" "$SANDBOX/skills/.superbeads-version" || _fail "version file tier != local"
assert_shims_never_invoked

# Round-trip: uninstall removes artifacts; designed settings backup MUST remain.
shape_uninstall
assert_no_file "$SANDBOX/skills/using-superpowers/SKILL.md"
assert_no_file "$SANDBOX/.claude/agents/yegge.md"
assert_no_file "$SANDBOX/.claude/hooks/superbeads-session-start.sh"
assert_no_file "$SANDBOX/.claude/hooks/superbeads"
assert_no_file "$SANDBOX/skills/.superbeads-version"
if [ -f "$SANDBOX/.claude/settings.json" ]; then
  assert_json "$SANDBOX/.claude/settings.json" "'superbeads' not in json.dumps(d)"
fi

# Opt-in round-trip: --with-yegge installs the agent; uninstall removes it (bead 3krn)
shape_install --with-yegge
assert_file "$SANDBOX/.claude/agents/yegge.md"
assert_all_skills "$SANDBOX/skills"
assert_shims_never_invoked
shape_uninstall
assert_no_file "$SANDBOX/.claude/agents/yegge.md"

shape_sandbox_teardown
fail_count
