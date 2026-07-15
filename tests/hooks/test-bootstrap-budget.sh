#!/usr/bin/env bash
# test-bootstrap-budget.sh — guard the always-injected session bootstrap size (ADR-0039).
# SCOPE: SKILL.md FILE bytes only. bd prime output and conditional warnings are
# deliberately OUT of budget — they are environment-sized and dedup-guarded.
# Do not "fix" this test to measure the full injection; that makes it flaky.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RENDER="$ROOT/tests/helpers/render-session-context.sh"
SKILL="$ROOT/skills/using-superpowers/SKILL.md"
CEILING=6144
WRAPPER_CEILING=1024
RENDERED_CEILING=3878
fail=0
size=$(wc -c < "$SKILL")
if [ "$size" -gt "$CEILING" ]; then
  echo "FAIL: using-superpowers/SKILL.md is ${size} bytes (> ${CEILING})"; fail=1
fi
# Static wrapper template (the session_context_raw assignment line in the hook,
# variable names unexpanded) must stay small too.
# Renamed session_context -> session_context_raw (Task 2, raw/one-escape contract) — pattern updated to match.
wrapper=$(grep -m1 'session_context_raw=' "$ROOT/hooks/session-start" | wc -c)
if [ "$wrapper" -gt "$WRAPPER_CEILING" ]; then
  echo "FAIL: session-start wrapper template is ${wrapper} bytes (> ${WRAPPER_CEILING})"; fail=1
fi
if [ "$fail" = 0 ]; then
  echo "PASS: bootstrap ${size}B <= ${CEILING}B; wrapper ${wrapper}B <= ${WRAPPER_CEILING}B"
fi

# --- composed-mode lifecycle budgets + latency (real --emit-plain seam) ---
sizes=""
for event in startup resume clear compact; do
  event_size=$(bash "$RENDER" "$event" | wc -c)
  [ "$event_size" -le "$RENDERED_CEILING" ] || {
    echo "FAIL: $event output ${event_size}B > ${RENDERED_CEILING}B budget"; fail=1;
  }
  sizes="${sizes}${event}=${event_size}B "
done

# latency budget: full composition under 5s wall-clock
t0=$(date +%s)
bash "$RENDER" startup >/dev/null
t1=$(date +%s)
[ $((t1 - t0)) -lt 5 ] || { echo "FAIL: hook took $((t1 - t0))s (>=5s budget)"; fail=1; }

if [ "$fail" = 0 ]; then
  echo "PASS: composed budgets ${sizes}(<= ${RENDERED_CEILING}B); latency $((t1 - t0))s < 5s"
fi
exit "$fail"
