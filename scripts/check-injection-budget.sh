#!/usr/bin/env bash
# check-injection-budget.sh — ratchet the per-session bootstrap skill size.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

LIMIT=560
SKILL="skills/using-superpowers/SKILL.md"

self_test() {
  local tmp
  tmp="$(mktemp -d)"
  printf 'one two three\n' > "$tmp/short.md"
  printf 'one two three four five six\n' > "$tmp/long.md"
  if [ "$(wc -w < "$tmp/short.md" | tr -d ' ')" -gt 3 ]; then
    echo "self-test FAIL: short fixture exceeded limit"
    rm -rf "$tmp"
    return 1
  fi
  if [ "$(wc -w < "$tmp/long.md" | tr -d ' ')" -le 3 ]; then
    echo "self-test FAIL: long fixture did not exceed limit"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
  echo "self-test OK: word-count budget distinguishes pass/fail"
}

if [ "${1:-}" = "--self-test" ]; then
  self_test
  exit $?
fi

words=$(wc -w < "$SKILL" | tr -d ' ')
if [ "$words" -le "$LIMIT" ]; then
  echo "injection-budget: OK ($SKILL $words words <= $LIMIT)"
else
  echo "injection-budget: FAIL ($SKILL $words words > $LIMIT)"
  exit 1
fi
