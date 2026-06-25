#!/usr/bin/env bash
# Asserts hooks/session-start emits the correct JSON dialect per harness env var.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/session-start"
fail=0
check() { # desc | env-assignment | jq-filter that must be non-empty
  local desc="$1" envset="$2" filter="$3"
  local out
  # shellcheck disable=SC2086  # $envset is intentionally word-split (space-separated KEY=VALUE pairs)
  out=$(env -i HOME="$HOME" PATH="$PATH" $envset bash "$HOOK" 2>/dev/null)
  if echo "$out" | jq -e "$filter" >/dev/null 2>&1; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc"; echo "  got: $out"; fail=1
  fi
}
check "Cursor → top-level additional_context"        "CURSOR_PLUGIN_ROOT=/x" '.additional_context'
check "Claude → nested additionalContext"            "CLAUDE_PLUGIN_ROOT=/x" '.hookSpecificOutput.additionalContext'
check "Copilot (with CLAUDE root) → top-level"       "CLAUDE_PLUGIN_ROOT=/x COPILOT_CLI=1" '.additionalContext'
check "Generic fallback → top-level additionalContext" "" '.additionalContext'
exit $fail
