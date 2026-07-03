#!/usr/bin/env bash
# run-hook-tests.sh — all tests/hooks/* (shell + node). Node tests SKIP visibly when node is absent.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit
rc=0
for t in tests/hooks/*.sh; do
  echo "── $t"
  if bash "$t"; then echo "   PASS"; else echo "   FAIL"; rc=1; fi
done
for t in tests/hooks/*.mjs; do
  [ -e "$t" ] || continue
  echo "── $t"
  if command -v node >/dev/null 2>&1; then
    if node "$t"; then echo "   PASS"; else echo "   FAIL"; rc=1; fi
  else
    echo "   SKIP (node not installed)"
  fi
done
exit "$rc"
