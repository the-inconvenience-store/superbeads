#!/usr/bin/env bash
# Asserts Claude/Codex hook manifests have SessionStart matchers containing all
# four sources, and Cursor's distinct manifest points at the checked-in hook shim.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0
for f in hooks/hooks.json hooks/codex-hooks.json; do
  m=$(jq -r '.hooks.SessionStart[0].matcher' "$ROOT/$f")
  for src in startup resume clear compact; do
    if echo "$m" | grep -q "$src"; then
      echo "PASS: $f contains '$src'"
    else
      echo "FAIL: $f missing '$src' (matcher: $m)"; fail=1
    fi
  done
done
cursor_cmd=$(jq -r '.hooks.sessionStart[0].command' "$ROOT/hooks/hooks-cursor.json")
if [ "$cursor_cmd" = "./hooks/run-hook.cmd session-start" ] && [ -f "$ROOT/hooks/run-hook.cmd" ]; then
  echo "PASS: hooks/hooks-cursor.json command targets hooks/run-hook.cmd"
else
  echo "FAIL: hooks/hooks-cursor.json unexpected command: $cursor_cmd"
  fail=1
fi
exit $fail
