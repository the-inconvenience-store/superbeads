#!/usr/bin/env bash
# Global plugin manifests must not auto-register SessionStart.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0
for f in hooks/hooks.json hooks/codex-hooks.json; do
  if [ -e "$ROOT/$f" ]; then
    echo "FAIL: global hook manifest still ships: $f"; fail=1
  else
    echo "PASS: global hook manifest absent: $f"
  fi
done
if jq -e 'has("hooks") | not' "$ROOT/.cursor-plugin/plugin.json" >/dev/null; then
  echo "PASS: Cursor plugin has no global hook registration"
else
  echo "FAIL: Cursor plugin still registers global hooks"; fail=1
fi
exit $fail
