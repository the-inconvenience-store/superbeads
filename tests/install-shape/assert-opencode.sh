#!/usr/bin/env bash
# assert-opencode.sh — Tier A: OpenCode skills-only global install + round-trip.
set -uo pipefail
# shellcheck source=tests/install-shape/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

shape_sandbox_setup opencode
trap 'shape_sandbox_teardown' EXIT
# shellcheck disable=SC2119  # bare call intentional — no extra install flags for this harness
shape_install

assert_all_skills "$SANDBOX/.config/opencode/skills"
assert_file "$SANDBOX/.config/opencode/skills/project-init/assets/session-start"
assert_no_file "$SANDBOX/.config/opencode/plugins/superbeads-plugin.ts"
assert_no_file "$SANDBOX/.config/opencode/hooks/session-start"
assert_in_log "OpenCode: installed"
assert_shims_never_invoked

shape_uninstall
assert_no_file "$SANDBOX/.config/opencode/plugins/superbeads-plugin.ts"
assert_no_file "$SANDBOX/.config/opencode/hooks/session-start"
assert_no_file "$SANDBOX/.config/opencode/skills/using-superpowers/SKILL.md"

shape_sandbox_teardown
fail_count
